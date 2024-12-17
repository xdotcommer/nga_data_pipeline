module NGA
  module Config
    def self.aws
      if ENV['environment'] == 'local'
        # Local development settings
        {
          region: ENV.fetch('AWS_REGION', 'us-east-1'),
          endpoint: 'http://localstack:4566',
          credentials: Aws::Credentials.new(
            ENV.fetch('AWS_ACCESS_KEY_ID', 'default_access_key'),
            ENV.fetch('AWS_SECRET_ACCESS_KEY', 'default_secret_key')
          )
        }
      else
        # AWS environment - just specify region and let AWS handle credentials
        {
          region: ENV.fetch('AWS_REGION', 'us-east-1')
        }
      end
    end
  end
end
