# frozen_string_literal: true

module Api
  # Resident Help fork (swy-ventures/docuseal).
  #
  # POST /api/templates/pdf
  #
  # Creates a template from one or more downloadable https URLs. This mirrors
  # what TemplatesUploadsController#create does for the web UI, so behaviour
  # (attachment processing, AcroForm field import, webhooks, search index)
  # stays identical to an upload through the browser.
  #
  # Params:
  #   name         optional template name (defaults to the first filename)
  #   url          https URL of a PDF/DOCX
  #   documents[]  alternative: [{ "file": "https://..." }, ...]
  #   folder_name  optional folder
  #
  # Response: { id, slug, name, fields_count, submitters, edit_url }
  class TemplatesPdfController < ApiBaseController
    load_and_authorize_resource :template, parent: false

    def create
      files = build_files

      if files.blank?
        return render json: { error: 'Provide `url` or `documents[].file` as downloadable https URLs' },
                      status: :unprocessable_content
      end

      @template.account = current_account
      @template.author = current_user
      @template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      @template.name = params[:name].presence || File.basename(files.first.original_filename, '.*')

      Templates.maybe_assign_access(@template)

      @template.save!

      documents, = Templates::CreateAttachments.call(@template, { files: }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      if @template.fields.blank?
        @template.fields = Templates::ProcessDocument.normalize_attachment_fields(@template, documents)
      end

      @template.update!(schema:)

      WebhookUrls.enqueue_events(@template, 'template.created')
      SearchEntries.enqueue_reindex(@template)

      render json: {
        id: @template.id,
        slug: @template.slug,
        name: @template.name,
        fields_count: @template.fields.size,
        submitters: @template.submitters,
        edit_url: "#{request.base_url}#{edit_template_path(@template)}"
      }
    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF is password protected' }, status: :unprocessable_content
    ensure
      Array(files).each do |file|
        file.tempfile.close!
      rescue StandardError
        nil
      end
    end

    private

    def build_files
      urls = Array.wrap(params[:url].presence)
      urls += Array.wrap(params[:documents]).filter_map { |doc| doc[:file].presence }

      urls.filter_map do |url|
        uri = Addressable::URI.parse(url.to_s)

        next unless uri.normalized_scheme == 'https' && uri.host.present?

        tempfile = Tempfile.new
        tempfile.binmode
        tempfile.write(DownloadUtils.call(url, validate: true).body)
        tempfile.rewind

        filename = File.basename(URI.decode_www_form_component(uri.path.to_s)).presence || 'document.pdf'

        ActionDispatch::Http::UploadedFile.new(
          tempfile:,
          filename:,
          type: Marcel::MimeType.for(tempfile)
        )
      end
    end
  end
end
