# frozen_string_literal: true

##
# Serves the built documentation site.
#
# Why a controller and not public/: anything under public/ is served before
# routing runs, so a deployment that wanted its documentation behind a login
# could never get there. Serving the build here keeps both outcomes one setting
# apart, and it keeps the whole tree — pages and assets alike — under the same
# rule. Splitting them would leave every image and script fetchable by anyone
# even when the setting says otherwise.
#
class DocsController < ApplicationController
  # Matches an opening script tag that has no src attribute. A tag that loads
  # from a file needs no nonce, and </script> cannot match because the pattern
  # requires 'script' immediately after '<'.
  INLINE_SCRIPT_TAG = /<script(?![^>]*\ssrc=)/
  # Nothing here renders application chrome, so the filters that prepare it are
  # pure cost. Authentication is re-declared below because it is conditional:
  # the inherited filter is unconditional and would make the site private in
  # every deployment.
  skip_before_action :setup_navigation,
                     :authenticate_user!,
                     :check_access_request_notifications,
                     :check_locked_user_notifications

  before_action :authenticate_user!, if: :require_login?

  # Rails refuses to serve a JavaScript response to a plain GET, on the grounds
  # that another site could include it with a script tag and read whatever
  # user-specific data it contains. Every file here is static build output,
  # byte-identical for every visitor and holding no user data, so there is
  # nothing for a cross-origin include to learn. Without this the site's own
  # bundles come back 422 and no page hydrates. Scoped to this controller, which
  # is read-only; the application-wide protection is untouched.
  skip_after_action :verify_same_origin_request

  def show
    file = resolve(params[:path].to_s)

    return render_missing_page if file.nil?
    return send_page(file) if file.extname == '.html'

    send_file file, type: content_type_for(file), disposition: :inline
  end

  private

  # The site ships two inline scripts, one of which applies the saved
  # light/dark preference before first paint. The policy has no unsafe-inline,
  # so each is given this response's nonce on the way out. That is only
  # possible because the page is served from here rather than from public/.
  def send_page(file)
    send_data nonce_inline_scripts(file.read),
              type: 'text/html',
              disposition: :inline
  end

  def nonce_inline_scripts(html)
    html.gsub(INLINE_SCRIPT_TAG, %(<script nonce="#{content_security_policy_nonce}"))
  end

  def require_login?
    Settings.docs.require_login
  end

  # Requests arrive without a file extension because the site is built with
  # clean URLs, so a page is looked up by three shapes: the exact file, the
  # same name with an .html extension, and a directory's index.
  def resolve(path)
    candidates(path).find { |candidate| candidate.file? && contained?(candidate) }
  end

  def candidates(path)
    base = root.join(path.delete_prefix('/'))

    [base, Pathname.new("#{base}.html"), base.join('index.html')]
  end

  # A request may not read outside the build. The candidate's REAL path — every
  # symlink resolved — must sit under the build root's real path, so dot-segment
  # traversal and a symlink pointing out of the build both fail closed. Only
  # existing files reach here (realpath raises on anything else), which resolve
  # guarantees by checking file? first.
  def contained?(candidate)
    real = candidate.realpath

    real.to_s.start_with?("#{root_realpath}/") || real == root_realpath
  end

  def root_realpath
    @root_realpath ||= root.realpath
  end

  def root
    DocsSite.output_directory
  end

  def content_type_for(file)
    Rack::Mime.mime_type(File.extname(file.to_s))
  end

  def render_missing_page
    render plain: 'Not found', status: :not_found
  end
end
