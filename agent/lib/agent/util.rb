module Bosh::Agent
  class Util
    class << self
      def unpack_blob(blobstore_id, install_path)
        base_dir = Bosh::Agent::Config.base_dir
        logger = Bosh::Agent::Config.logger

        bsc_options = Bosh::Agent::Config.blobstore_options
        blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bsc_options)

        data_tmp = File.join(base_dir, 'data', 'tmp')
        FileUtils.mkdir_p(data_tmp)

        Tempfile.open(blobstore_id, data_tmp) do |tf|
          logger.info("Retrieving blob: #{blobstore_id}")

          tf.write(blobstore_client.get(blobstore_id))
          tf.flush

          FileUtils.mkdir_p(install_path)

          blob_data_file = tf.path

          logger.info("Installing to: #{install_path}")
          Dir.chdir(install_path) do
            output = `tar zxvf #{blob_data_file}`
            raise Bosh::Agent::MessageHandlerError,
              "Failed to unpack blob: #{output}" unless $?.exitstatus == 0
          end
        end

      end

      # Provide binding for a particular variable
      def config_binding(config)
        @name = config['job']['name']
        @index = config['index']
        @properties = config['properties']
        @spec = config.to_openstruct
        binding
      end

      def partition_disk(dev, sfdisk_input)
        logger = Bosh::Agent::Config.logger
        if File.blockdev?(dev)
          sfdisk_cmd = "echo \"#{sfdisk_input}\" | sfdisk -uM #{dev}"
          output = %x[#{sfdisk_cmd}]
          unless $? == 0
            logger.info("failed to parition #{dev}")
            logger.info(ouput)
          end
        end
      end

      def settings
        base_dir = Bosh::Agent::Config.base_dir
        settings_dir = File.join(base_dir, 'bosh', 'settings')

        begin
          File.read('/dev/cdrom', 0)
        rescue Errno::E123 # ENOMEDIUM
          raise Bosh::Agent::LoadSettingsError, 'No bosh cdrom env'
        end

        FileUtils.mkdir_p(settings_dir)
        FileUtils.chmod(700, settings_dir)

        output = `mount /dev/cdrom #{settings_dir} 2>&1`
        raise Bosh::Agent::LoadSettingsError,
          "Failed to mount settings on #{settings_dir}: #{output}" unless $?.exitstatus == 0

        settings_json = File.read(File.join(settings_dir, 'env'))

        `umount #{settings_dir} 2>&1`
        `eject /dev/cdrom`

        settings = Yajl::Parser.new.parse(settings_json)

        cache = File.join(base_dir, 'bosh', 'settings.json')
        File.open(cache, 'w') { |f| f.write(settings_json) }

        settings
      end

    end
  end
end
