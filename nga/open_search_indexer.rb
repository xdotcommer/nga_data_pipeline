require_relative 'base'
require 'aws-sdk-opensearchserverless'
require 'csv'
require 'net/http'
require 'uri'
require 'json'
require 'aws-sigv4'

module NGA
  class OpenSearchIndexer < NGA::Base
    BATCH_SIZE = 100

    def self.lambda_handler(event:, context:)
      new.import!
    end

    def initialize
      puts 'Initializing OpenSearchIndexer...'
      super()

      @collection_name = "#{ENV.fetch('PROJECT_NAME')}-#{ENV.fetch('ENVIRONMENT')}"
      @index_name = 'artworks' # Using a simpler name for the index within the collection

      puts "Using collection name: #{@collection_name}"

      # Initialize OpenSearch Serverless client with proper credentials
      @client = Aws::OpenSearchServerless::Client.new(
        NGA::Config.aws.merge(
          region: ENV.fetch('AWS_REGION', 'us-east-1')
        )
      )

      # Initialize AWS Signer for OpenSearch requests
      @signer = Aws::Sigv4::Signer.new(
        service: 'aoss',
        region: ENV.fetch('AWS_REGION', 'us-east-1'),
        access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
        secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
        session_token: ENV['AWS_SESSION_TOKEN']
      )
    end

    def import!
      ensure_collection_exists
      wait_for_collection_active

      puts "OpenSearch endpoint from environment: #{ENV['AWS_OPENSEARCH_ENDPOINT']}"
      endpoint = ENV['AWS_OPENSEARCH_ENDPOINT']
      puts "Collection endpoint: #{endpoint}"

      # Add this line
      ensure_index_exists

      timestamp = get_latest_timestamp
      objects = fetch_from_s3("raw/#{timestamp}/objects.csv")
      images = fetch_from_s3("raw/#{timestamp}/published_images.csv")

      puts "Processing #{objects.count} objects..."

      images_by_object = index_images(images)
      process_objects(objects, images_by_object)

      { indexed_count: objects.count }
    end

    def wait_for_collection_active
      puts "Waiting for collection '#{@collection_name}' to become active..."
      max_attempts = 30
      attempts = 0

      loop do
        response = @client.batch_get_collection(names: [@collection_name])
        collection = response.collection_details.first
        status = collection.status

        if status == 'ACTIVE'
          puts 'Collection is now active'
          @collection_endpoint = collection.collection_endpoint
          break
        elsif attempts >= max_attempts
          raise "Collection failed to become active after #{max_attempts} attempts"
        end

        attempts += 1
        sleep(10)
      end
    end

    def ensure_index_exists
      puts "Ensuring index '#{@index_name}' exists..."
      endpoint = ENV['AWS_OPENSEARCH_ENDPOINT']

      begin
        signed_request(:put, endpoint, "/#{@index_name}", {
          settings: {
            number_of_shards: 3,
            number_of_replicas: 1,
            refresh_interval: '30s'
          },
          mappings: {
            properties: {
              id: { type: 'keyword' },
              accession_number: { type: 'keyword' },
              title: { type: 'text', analyzer: 'english' },
              date: { type: 'text' },
              medium: { type: 'text' },
              attribution: { type: 'text' },
              credit_line: { type: 'text' },
              classification: { type: 'keyword' },
              description: { type: 'text', analyzer: 'english' },
              images: {
                type: 'nested',
                properties: {
                  uuid: { type: 'keyword' },
                  iiif_url: { type: 'keyword' },
                  thumbnail_url: { type: 'keyword' }
                }
              }
            }
          }
        }.to_json)
        puts "Successfully created index '#{@index_name}'"
      rescue StandardError => e
        raise e unless e.message.include?('resource_already_exists_exception')

        puts "Index '#{@index_name}' already exists"
      end
    end

    def process_objects(objects, images_by_object)
      endpoint = ENV['AWS_OPENSEARCH_ENDPOINT']
      total_processed = 0

      objects.each_slice(BATCH_SIZE) do |batch|
        bulk_body = create_bulk_body(batch, images_by_object)
        next if bulk_body.empty?

        # Add the index name to the _bulk endpoint
        response = signed_request(:post, endpoint, "/#{@index_name}/_bulk", bulk_body)
        report_bulk_errors(response)

        total_processed += batch.size
        puts "Processed #{total_processed} objects..." if (total_processed % 1000).zero?
      end

      puts "Completed processing #{total_processed} objects"
    end

    def create_bulk_body(batch, images_by_object)
      batch.map do |row|
        object_id = row['objectid']
        images = images_by_object[object_id] || []

        [
          { index: { _index: @index_name, _id: object_id } }.to_json,
          {
            id: object_id,
            accession_number: row['accessionnum'],
            title: row['title'],
            date: row['displaydate'],
            medium: row['medium'],
            attribution: row['attribution'],
            credit_line: row['creditline'],
            classification: row['classification'],
            description: row['provenancetext'],
            images: images
          }.to_json
        ]
      end.flatten.join("\n") + "\n"
    end

    private

    def ensure_collection_exists
      puts "Checking if collection '#{@collection_name}' exists..."
      collections = @client.list_collections.collection_summaries
      return if collections.any? { |col| col.name == @collection_name }

      puts "Creating collection '#{@collection_name}'..."
      @client.create_collection(
        name: @collection_name,
        type: 'SEARCH',
        description: 'NGA artwork collection'
      )
    end

    def signed_request(method, endpoint, path, body = nil)
      uri = URI("#{endpoint}#{path}")
      puts "Making #{method.upcase} request to: #{uri}"

      # Setup the HTTP request
      request_class = case method
                      when :get then Net::HTTP::Get
                      when :post then Net::HTTP::Post
                      when :put then Net::HTTP::Put
                      else raise "Unsupported HTTP method: #{method}"
                      end

      request = request_class.new(uri)
      request.body = body if body

      # Add required headers
      request.content_type = 'application/json' if body
      request['host'] = uri.host
      request['x-amz-date'] = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
      request['x-amz-security-token'] = ENV['AWS_SESSION_TOKEN'] if ENV['AWS_SESSION_TOKEN']

      # Create canonical request
      canonical_headers = {
        'host' => uri.host,
        'x-amz-date' => request['x-amz-date']
      }
      canonical_headers['x-amz-security-token'] = ENV['AWS_SESSION_TOKEN'] if ENV['AWS_SESSION_TOKEN']

      # Generate signature
      signer = Aws::Sigv4::Signer.new(
        service: 'aoss',
        region: ENV.fetch('AWS_REGION', 'us-east-1'),
        access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
        secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
        session_token: ENV['AWS_SESSION_TOKEN']
      )

      signature = signer.sign_request(
        http_method: method.to_s.upcase,
        url: uri.to_s,
        headers: canonical_headers,
        body: body
      )

      # Add authorization headers
      request['Authorization'] = signature.headers['authorization']
      request['x-amz-date'] = signature.headers['x-amz-date']
      request['x-amz-content-sha256'] = signature.headers['x-amz-content-sha256']
      if signature.headers['x-amz-security-token']
        request['x-amz-security-token'] =
          signature.headers['x-amz-security-token']
      end

      # Send request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        puts 'Full Response Details:'
        puts "Status Code: #{response.code}"
        puts "Response Body: #{response.body}"
        puts 'Response Headers:'
        response.each_header { |name, value| puts "  #{name}: #{value}" }

        # More informative error raising
        raise "Request failed: #{response.code} - Detailed Error: #{response.body}"
      end

      response
    end

    def report_bulk_errors(response)
      result = JSON.parse(response.body)
      return unless result['errors']

      result['items'].each_with_index do |item, index|
        next unless item['index'] && item['index']['error']

        puts "Error indexing document #{index}: #{item['index']['error']}"
      end
    end

    def get_latest_timestamp
      puts 'Finding latest timestamp in S3...'

      response = @s3.list_objects_v2(
        bucket: ENV['AWS_S3_BUCKET'],
        prefix: 'raw/'
      )

      # Get all timestamps from folder names like 'raw/20241215_123456/'
      timestamps = response.contents
                           .map { |obj| obj.key.split('/')[1] }
                           .uniq
                           .compact
                           .sort
                           .reverse

      latest = timestamps.first
      puts "Found latest timestamp: #{latest}"
      latest
    end

    def index_images(images_csv)
      images_by_object = {}

      images_csv.each do |row|
        object_id = row['depictstmsobjectid']
        next unless object_id

        images_by_object[object_id] ||= []
        images_by_object[object_id] << {
          uuid: row['uuid'],
          iiif_url: row['iiifurl'],
          thumbnail_url: row['iiifthumburl']
        }
      end

      images_by_object
    end

    def fetch_from_s3(key)
      puts "Fetching from S3: #{key}"
      response = @s3.get_object(bucket: ENV['AWS_S3_BUCKET'], key: key)
      CSV.parse(response.body.read, headers: true)
    rescue Aws::S3::Errors::NoSuchKey => e
      puts "Error: S3 key '#{key}' not found. #{e.message}"
      raise
    rescue CSV::MalformedCSVError => e
      puts "Error: Malformed CSV data for key '#{key}'. #{e.message}"
      raise
    end
  end
end
