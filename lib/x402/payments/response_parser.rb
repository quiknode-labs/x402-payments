# frozen_string_literal: true

require "json"
require "base64"

module X402
  module Payments
    class ResponseParser
      class ParseError < Error; end

      attr_reader :response

      def initialize(response)
        @response = response
      end

      def parse
        version = detect_version
        data = extract_data(version)

        normalize(data, version)
      end

      def detect_version
        if has_header?(V2::Headers::PAYMENT_REQUIRED_HEADER)
          2
        elsif body_json && body_json["x402Version"]
          body_json["x402Version"]
        else
          1
        end
      end

      private

      def extract_data(version)
        case version
        when 2
          extract_v2_data
        else
          extract_v1_data
        end
      end

      def extract_v1_data
        data = body_json
        raise ParseError, "Could not parse v1 402 response body" unless data

        data
      end

      def extract_v2_data
        header_value = get_header(V2::Headers::PAYMENT_REQUIRED_HEADER)
        raise ParseError, "Missing #{V2::Headers::PAYMENT_REQUIRED_HEADER} header" unless header_value

        decoded = Base64.strict_decode64(header_value)
        JSON.parse(decoded)
      rescue ArgumentError, JSON::ParserError => e
        raise ParseError, "Could not parse v2 PAYMENT-REQUIRED header: #{e.message}"
      end

      def normalize(data, version)
        case version
        when 2
          normalize_v2(data)
        else
          normalize_v1(data)
        end
      end

      def normalize_v1(data)
        accepts = data["accepts"] || []

        {
          version: 1,
          error: data["error"],
          resource: extract_v1_resource(accepts.first),
          accepts: accepts.map { |a| normalize_v1_accept(a) }
        }
      end

      def normalize_v2(data)
        resource_data = data["resource"] || {}
        accepts = data["accepts"] || []

        {
          version: 2,
          error: data["error"],
          resource: {
            url: resource_data["url"],
            description: resource_data["description"],
            mime_type: resource_data["mimeType"]
          },
          accepts: accepts.map { |a| normalize_v2_accept(a) },
          extensions: data["extensions"] || {}
        }
      end

      def extract_v1_resource(accept)
        return {} unless accept

        {
          url: accept["resource"],
          description: accept["description"],
          mime_type: accept["mimeType"]
        }
      end

      def normalize_v1_accept(accept)
        {
          scheme: accept["scheme"],
          network: accept["network"],
          amount: accept["maxAmountRequired"],
          asset: accept["asset"],
          pay_to: accept["payTo"],
          max_timeout_seconds: accept["maxTimeoutSeconds"],
          extra: accept["extra"]
        }
      end

      def normalize_v2_accept(accept)
        {
          scheme: accept["scheme"],
          network: accept["network"],
          amount: accept["amount"],
          asset: accept["asset"],
          pay_to: accept["payTo"],
          max_timeout_seconds: accept["maxTimeoutSeconds"],
          extra: accept["extra"]
        }
      end

      def body_json
        @body_json ||= parse_body
      end

      def parse_body
        body_content = response_body
        return nil if body_content.nil? || body_content.empty?

        JSON.parse(body_content)
      rescue JSON::ParserError
        nil
      end

      def response_body
        if response.respond_to?(:body)
          response.body
        elsif response.is_a?(Hash)
          response[:body] || response["body"]
        else
          response.to_s
        end
      end

      def has_header?(name)
        !get_header(name).nil?
      end

      def get_header(name)
        if response.respond_to?(:headers)
          response.headers[name] || response.headers[name.downcase]
        elsif response.respond_to?(:[])
          headers = response[:headers] || response["headers"] || {}
          headers[name] || headers[name.downcase]
        elsif response.respond_to?(:get_header)
          response.get_header(name)
        else
          nil
        end
      end

      class << self
        def parse(response)
          new(response).parse
        end

        def detect_version(response)
          new(response).detect_version
        end
      end
    end
  end
end
