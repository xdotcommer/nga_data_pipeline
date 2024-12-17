require 'aws-sdk-s3'
require_relative 'config'

module NGA
  class Base
    def initialize
      @s3 = Aws::S3::Client.new(
        NGA::Config.aws.merge(
          force_path_style: ENV['LAMBDA_TASK_ROOT'] ? true : false
        )
      )
      @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    end
  end
end
