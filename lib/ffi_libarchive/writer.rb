# frozen_string_literal: true

module Archive
  class Writer < BaseArchive
    private_class_method :new

    # @param [String] file_name
    # @return [Writer]
    # @yieldparam [Writer]
    def self.open_filename(file_name, compression, format)
      if block_given?
        writer = open_filename file_name, compression, format

        begin
          yield writer
        ensure
          writer.close if writer.respond_to?(:close)
        end
      else
        new file_name: file_name, compression: compression, format: format
      end
    end

    # @param [String] string
    # @return [Writer]
    # @yieldparam [Writer]
    def self.open_memory(string, compression, format)
      if block_given?
        writer = open_memory string, compression, format

        begin
          yield writer
        ensure
          writer.close if writer.respond_to?(:close)
        end
      else
        new memory: string, compression: compression, format: format
      end
    end

    # @param [Hash] params
    # @option params [Object] :compression
    # @option params [Object] :format
    # @option params [String] :file_name
    # @option params [String] :memory
    def initialize(params = {})
      super C.method(:archive_write_new), C.method(:archive_write_free)

      begin
        init_compression params[:compression]
        init_format params[:format]

        if params[:file_name]
          init_for_filename params[:file_name]
        elsif params[:memory]
          init_for_memory params[:memory]
        end
      rescue StandardError
        close
        raise
      end
    end

    # @return [Entry]
    # @yieldparam [Entry]
    def new_entry
      entry = Entry.new

      if block_given?
        begin
          yield entry
        ensure
          entry.close
        end
      else
        entry
      end
    end

    # @raise [ArgumentError] If no block given
    # @return [NilClass]
    # @yieldparam [Entry]
    # @yieldreturn [String]
    def add_entry
      raise ArgumentError, 'No block given' unless block_given?

      entry = Entry.new
      begin
        data = yield entry

        if data
          entry.size = data.bytesize

          write_header entry
          write_data data
        else
          write_header entry
        end

        nil
      ensure
        entry.close
      end
    end

    # @param [Array<String>] args
    # @return [Integer]
    # @raise [ArgumentError]
    # @yieldreturn [String]
    def write_data(*args)
      if block_given?
        raise ArgumentError, 'Not support arguments when block given' unless args.empty?

        len = 0
        loop do
          str = yield len
          n   = str.is_a?(String) ? C.archive_write_data(archive, Utils.get_memory_ptr(str), str.bytesize) : 0

          raise Error, self if n < 0
          break if n.zero?

          len += n
        end

        len
      else
        str = args[0]
        raise ArgumentError, 'Invalid String argument' unless str.is_a?(String)

        n = C.archive_write_data(archive, Utils.get_memory_ptr(str), str.bytesize)
        raise Error, self if n < 0

        n
      end
    end

    # @param [Entry] entry
    def write_header(entry)
      raise Error, self if C.archive_write_header(archive, entry.entry) != C::OK
    end

    def close
      super
      @write_callback = nil
    end

    protected

    def init_compression(compression)
      raise ArgumentError, 'Missing :compression argument' if !compression || compression.to_s.empty?

      unless compression.is_a?(Integer) || compression.is_a?(String)
        prefix      = C.respond_to?(:archive_write_add_filter) ? 'FILTER' : 'COMPRESSION'
        compression = Archive.const_get("#{prefix}_#{compression}".upcase)
      end

      raise Error, self if C.archive_write_set_compression(archive, compression) != C::OK
    end

    def init_format(format)
      raise ArgumentError, 'Missing :format argument' if !format || format.to_s.empty?

      format = Archive.const_get("FORMAT_#{format}".upcase) unless format.is_a?(Integer)
      raise Error, self if C.archive_write_set_format(archive, format) != C::OK
    end

    def init_for_filename(file_name)
      raise Error, self if C.archive_write_open_filename(archive, file_name) != C::OK
    end

    def init_for_memory(memory)
      C.archive_write_set_bytes_in_last_block(archive, 1) if C.archive_write_get_bytes_in_last_block(archive) < 0

      @write_callback = proc do |_ar, _client_data, buffer, length|
        memory << buffer.get_bytes(0, length)
        length
      end

      null_ptr = FFI::Pointer::NULL
      raise Error, self if C.archive_write_open(archive, null_ptr, null_ptr, @write_callback, null_ptr) != C::OK
    end
  end
end
