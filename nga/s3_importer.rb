require_relative 'base'
require 'down'

module NGA
  class S3Importer < NGA::Base
    def self.lambda_handler(event:, context:)
      new.import!
    end

    def import!
      files = {
        'objects.csv' => fetch_csv('objects.csv'),
        'published_images.csv' => fetch_csv('published_images.csv')
      }

      files.each do |filename, content|
        store_in_s3(content, filename)
        store_parquet_version(content, filename)
      end

      { timestamp: @timestamp, files: files.keys }
    end

    private

    def fetch_csv(filename)
      url = "https://github.com/NationalGalleryOfArt/opendata/raw/main/data/#{filename}"
      Down.download(url).read
    end

    def store_in_s3(content, filename)
      @s3.put_object(
        bucket: ENV['AWS_S3_BUCKET'],
        key: "raw/#{@timestamp}/#{filename}",
        body: content
      )
    end

    def store_parquet_version(content, filename)
      @s3.put_object(
        bucket: ENV['AWS_S3_BUCKET'], # TODO: - change to the S3 Table bucket
        key: "parquet/#{@timestamp}/#{filename.gsub('.csv', '.parquet')}",
        body: content
      )
    end
  end
end
