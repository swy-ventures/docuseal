# frozen_string_literal: true

# Resident Help fork (swy-ventures/docuseal).
#
# Allows the signing form (/s/:slug and its completed/success pages) to be
# rendered inside an iframe on the client portal. Rails adds
# X-Frame-Options: SAMEORIGIN by default; this concern removes it and emits a
# Content-Security-Policy frame-ancestors directive instead, limited to the
# origins listed in RH_FRAME_ANCESTORS (space separated), e.g.
#
#   RH_FRAME_ANCESTORS="https://residenthelp.org https://www.residenthelp.org"
#
# When the variable is unset or empty, behaviour is identical to upstream.
module RhEmbeddable
  extend ActiveSupport::Concern

  included do
    after_action :rh_allow_frame_ancestors
  end

  private

  def rh_allow_frame_ancestors
    origins = ENV.fetch('RH_FRAME_ANCESTORS', '').split

    return if origins.blank?

    response.headers.delete('X-Frame-Options')
    response.headers['Content-Security-Policy'] = "frame-ancestors 'self' #{origins.join(' ')}"
  end
end
