module OmniAuth
  module LoginDotGov
    class Callback
      attr_reader :session, :client, :id_token, :userinfo

      def initialize(session:, client:)
        @session = session.to_h
        @client = client
      end

      def call(params)
        verify_state(params)
        handle_error(params) if params['error']
        @id_token = IdTokenRequest.new(
          code: params['code'],
          client: client
        ).request_id_token
        id_token.verify_nonce(session.dig('oidc', 'nonce_digest'))
        @userinfo = UserinfoRequest.new(
          id_token: id_token,
          client: client
        ).request_userinfo
      end

      private

      def verify_state(params)
        cb_state = params['state']
        cb_state_digest = OpenSSL::Digest::SHA256.base64digest(cb_state)
        return if SecureCompare.compare(
          cb_state_digest,
          session.dig('oidc', 'state_digest')
        )
        raise CallbackStateMismatchError
      end

      def handle_error(params)
        error_type = case params['error']
                     when 'access_denied'
                       CallbackAccessDeniedError
                     when 'invalid_request'
                       CallbackInvalidRequestError
                     else
                       RuntimeError
                     end
        raise error_type, params['error_description']
      end
    end
  end
end