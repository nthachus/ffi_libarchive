# frozen_string_literal: true

module Archive
  class Entry
    # region File-type Constants

    S_IFMT   = 0o170000 # bits mask
    S_IFSOCK = 0o140000
    S_IFLNK  = 0o120000
    S_IFREG  = 0o100000
    S_IFBLK  = 0o060000
    S_IFDIR  = 0o040000
    S_IFCHR  = 0o020000
    S_IFIFO  = 0o010000

    SOCKET           = S_IFSOCK
    SYMBOLIC_LINK    = S_IFLNK
    FILE             = S_IFREG # regular file
    BLOCK_DEVICE     = S_IFBLK # block special device
    DIRECTORY        = S_IFDIR
    CHARACTER_DEVICE = S_IFCHR # character special device
    FIFO             = S_IFIFO # named pipe (FIFO)

    def self.file_types
      @file_types ||= Hash[constants.reject { |k| k =~ /^S_/ }.map { |k| [k.downcase, const_get(k)] }]
    end

    # endregion

    # @param [FFI::Pointer]
    # @return [Entry]
    def self.from_pointer(entry)
      new entry
    end

    # @param [FFI::Pointer] entry
    def initialize(entry = nil)
      if entry
        @entry = entry
      else
        @entry = C.archive_entry_new
        raise Error, 'No entry object' unless @entry
      end

      if block_given?
        begin
          yield self
        ensure
          close
        end
      else
        ObjectSpace.define_finalizer(self, method(:close).to_proc)
      end
    end

    def close
      # TODO: do we need synchronization here?
      C.archive_entry_free(@entry) if @entry
    ensure
      @entry = nil
    end

    # @return [FFI::Pointer]
    attr_reader :entry

    class << self
      protected

      # @param [Symbol] api   API method
      # @param [Hash] opts
      # @option opts [#to_sym] :name  Method name
      # @option opts [Boolean] :maybe Skip undefined method?
      # @option opts [#call] :post   The result transformer
      # @option opts [#call] :pre    The arguments processor
      def attach_attribute(api, opts = {})
        opts[:name] ||= api.to_s.sub(/^archive_entry_/, '').sub(/_is_.*$/, '\0?')

        define_method(opts[:name].to_sym) do |*args|
          opts[:pre].call(args) if opts[:pre].respond_to?(:call)

          result = C.respond_to?(api) || !opts[:maybe] ? C.send(api, *args.unshift(entry)) : nil
          opts[:post].respond_to?(:call) ? opts[:post].call(result) : result
        end
      end

      def proc_time_at
        @proc_time_at ||= Time.method(:at)
      end

      def proc_2_args_to_i
        @proc_2_args_to_i ||= proc { |args| args.fill(0, args.size..1).map!(&:to_i) }
      end

      def proc_is_nonzero
        @proc_is_nonzero ||= 0.method(:!=)
      end

      def proc_read_wide_string
        @proc_read_wide_string ||= Utils.method(:read_wide_string)
      end

      def proc_string_arg_to_wide
        @proc_string_arg_to_wide ||= proc { |args| args.map! { |s| Utils.to_wide_string s } }
      end
    end

    # region Access time
    # @!method atime
    #   @return [Time]
    attach_attribute :archive_entry_atime, post: proc_time_at

    # @!method set_atime(time, nsec = 0)
    #   @param [Time, #to_i] time
    #   @param [Integer, #to_i] nsec
    attach_attribute :archive_entry_set_atime, pre: proc_2_args_to_i

    alias atime= set_atime

    # @!method atime_is_set?
    #   @return [Boolean]
    attach_attribute :archive_entry_atime_is_set, post: proc_is_nonzero

    # @!method atime_nsec
    #   @return [Integer] :long
    attach_attribute :archive_entry_atime_nsec

    # @!method unset_atime
    attach_attribute :archive_entry_unset_atime
    # endregion

    # region Creation time
    # @!method birthtime
    #   @return [Time]
    attach_attribute :archive_entry_birthtime, post: proc_time_at

    # @!method set_birthtime(time, nsec = 0)
    #   @param [Time, #to_i] time
    #   @param [Integer, #to_i] nsec
    attach_attribute :archive_entry_set_birthtime, pre: proc_2_args_to_i

    alias birthtime= set_birthtime

    # @!method birthtime_is_set?
    #   @return [Boolean]
    attach_attribute :archive_entry_birthtime_is_set, post: proc_is_nonzero

    # @!method birthtime_nsec
    #   @return [Integer] :long
    attach_attribute :archive_entry_birthtime_nsec

    # @!method unset_birthtime
    attach_attribute :archive_entry_unset_birthtime
    # endregion

    # region Change time
    # @!method ctime
    #   @return [Time]
    attach_attribute :archive_entry_ctime, post: proc_time_at

    # @!method set_ctime(time, nsec = 0)
    #   @param [Time, #to_i] time
    #   @param [Integer, #to_i] nsec
    attach_attribute :archive_entry_set_ctime, pre: proc_2_args_to_i

    alias ctime= set_ctime

    # @!method ctime_is_set?
    #   @return [Boolean]
    attach_attribute :archive_entry_ctime_is_set, post: proc_is_nonzero

    # @!method ctime_nsec
    #   @return [Integer] :long
    attach_attribute :archive_entry_ctime_nsec

    # @!method unset_ctime
    attach_attribute :archive_entry_unset_ctime
    # endregion

    # region File-type

    # @!method filetype
    #   @return [Integer] :mode_t
    attach_attribute :archive_entry_filetype

    # @!method filetype=(type)
    #   @param [Integer, #to_s] type
    attach_attribute(
      :archive_entry_set_filetype,
      name: 'filetype=', pre: ->(args) { args.map! { |t| t.is_a?(Integer) ? t : const_get(t.to_s.upcase) } }
    )

    # @!method block_device?
    #   @return [Boolean]
    # @!method character_device?
    #   @return [Boolean]
    # @!method directory?
    #   @return [Boolean]
    # @!method fifo?
    #   @return [Boolean]
    # @!method file?
    #   @return [Boolean]
    # @!method socket?
    #   @return [Boolean]
    # @!method symbolic_link?
    #   @return [Boolean]
    file_types.each do |k, v|
      define_method("#{k}?".to_sym) { (filetype & S_IFMT) == v }
    end

    alias regular? file?
    alias block_special? block_device?
    alias character_special? character_device?

    # @return [Symbol]
    def filetype_s
      self.class.file_types.key(filetype & S_IFMT)
    end

    # endregion

    # region File status

    # @!method stat
    #   @return [FFI::Pointer]
    attach_attribute :archive_entry_stat

    # @param [String, FFI::Pointer] filename
    def copy_lstat(filename)
      copy_stat_from(filename.is_a?(String) ? File.lstat(filename) : filename)
    end

    # @param [String, FFI::Pointer] filename
    def copy_stat(filename)
      copy_stat_from(filename.is_a?(String) ? File.stat(filename) : filename)
    end

    # @private
    # @param [FFI::Pointer, File::Stat] stat
    def copy_stat_from(stat)
      if stat.respond_to?(:null?) && !stat.null?
        C.archive_entry_copy_stat(entry, stat)

      elsif stat.is_a?(File::Stat)
        %w[dev gid uid ino nlink rdev size mode].each do |fn|
          # @type [Integer]
          f = stat.send(fn)
          send "#{fn}=", f if f
        end

        %w[atime ctime mtime birthtime].each do |fn|
          # @type [Time]
          f = stat.respond_to?(fn) ? stat.send(fn) : nil
          send "set_#{fn}", f, f.tv_nsec if f
        end
      else
        raise ArgumentError, "Copying stat for #{stat.class} is not supported"
      end
    end

    # endregion

    # region Device number
    # @!method dev
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_dev

    # @!method dev=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_dev, name: 'dev='

    # @!method devmajor
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_devmajor

    # @!method devmajor=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_devmajor, name: 'devmajor='

    # @!method devminor
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_devminor

    # @!method devminor=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_devminor, name: 'devminor='
    # endregion

    # region File flags/attributes (see #lsattr)
    # @return [Array<Integer>]  of [:set, :clear]
    def fflags
      set   = FFI::MemoryPointer.new :ulong
      clear = FFI::MemoryPointer.new :ulong
      C.archive_entry_fflags(entry, set, clear)

      [set.get_ulong(0), clear.get_ulong(0)]
    end

    # @!method set_fflags(set, clear)
    #   @param [Integer] set
    #   @param [Integer] clear
    attach_attribute :archive_entry_set_fflags

    # @!method fflags_text
    #   @return [String]
    attach_attribute :archive_entry_fflags_text

    # @!method copy_fflags_text(fflags_text)
    #   @param [String] fflags_text
    #   @return [String]  Invalid token string, or NULL if success
    attach_attribute :archive_entry_copy_fflags_text

    alias fflags_text= copy_fflags_text
    # endregion

    # region Group ownership
    # @!method gid
    #   @return [Integer] :int64_t
    attach_attribute :archive_entry_gid

    # @!method gid=(gid)
    #   @param [Integer] gid
    attach_attribute :archive_entry_set_gid, name: 'gid='

    # @!method gname
    #   @return [String]
    attach_attribute :archive_entry_gname

    # @!method gname=(gname)
    #   @param [String] gname
    attach_attribute :archive_entry_set_gname, name: 'gname='

    # @!method copy_gname(gname)
    #   @param [String] gname
    attach_attribute :archive_entry_copy_gname
    # endregion

    # region Links

    # @!method hardlink
    #   @return [String]
    attach_attribute :archive_entry_hardlink

    # @!method hardlink=(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_set_hardlink, name: 'hardlink='

    # @!method copy_hardlink(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_copy_hardlink

    # @!method link=(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_set_link, name: 'link='

    # @!method copy_link(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_copy_link

    # @!method symlink
    #   @return [String]
    attach_attribute :archive_entry_symlink

    # @!method symlink=(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_set_symlink, name: 'symlink='

    # @!method copy_symlink(lnk)
    #   @param [String] lnk
    attach_attribute :archive_entry_copy_symlink

    # endregion

    # @!method ino
    #   @return [Integer] :int64_t of inode number
    attach_attribute :archive_entry_ino

    # @!method ino=(ino)
    #   @param [String] ino inode number
    attach_attribute :archive_entry_set_ino, name: 'ino='

    # region File permissions

    # @!method mode
    #   @return [Integer] :mode_t
    attach_attribute :archive_entry_mode

    # @!method mode=(mode)
    #   @param [Integer] mode File protection (see #filetype)
    attach_attribute :archive_entry_set_mode, name: 'mode='

    # @!method perm
    #   @return [Integer] :mode_t
    attach_attribute :archive_entry_perm

    # @!method perm=(perm)
    #   @param [Integer] perm of :mode_t
    attach_attribute :archive_entry_set_perm, name: 'perm='

    # @!method strmode
    #   @return [String]
    attach_attribute :archive_entry_strmode

    # endregion

    # region Modification time
    # @!method mtime
    #   @return [Time]
    attach_attribute :archive_entry_mtime, post: proc_time_at

    # @!method set_mtime(time, nsec = 0)
    #   @param [Time, #to_i] time
    #   @param [Integer, #to_i] nsec
    attach_attribute :archive_entry_set_mtime, pre: proc_2_args_to_i

    alias mtime= set_mtime

    # @!method mtime_is_set?
    #   @return [Boolean]
    attach_attribute :archive_entry_mtime_is_set, post: proc_is_nonzero

    # @!method mtime_nsec
    #   @return [Integer] :long
    attach_attribute :archive_entry_mtime_nsec

    # @!method unset_mtime
    attach_attribute :archive_entry_unset_mtime
    # endregion

    # @!method nlink
    #   @return [Integer] :uint
    attach_attribute :archive_entry_nlink

    # @!method nlink=(nlink)
    #   @param [Integer] nlink  Number of hard links / files in a directory
    attach_attribute :archive_entry_set_nlink, name: 'nlink='

    # region File path
    # @!method pathname
    #   @return [String]
    attach_attribute :archive_entry_pathname

    # @!method pathname=(path)
    #   @param [String] path
    attach_attribute :archive_entry_set_pathname, name: 'pathname='

    # @!method pathname_w
    #   @return [String]
    attach_attribute :archive_entry_pathname_w, maybe: true, post: proc_read_wide_string

    # @!method pathname_w=(path)
    #   @param [String] path
    attach_attribute :archive_entry_copy_pathname_w, name: 'pathname_w=', pre: proc_string_arg_to_wide

    # @!method copy_pathname(file_name)
    #   @param [String] file_name
    attach_attribute :archive_entry_copy_pathname
    # endregion

    # region Root device ID (if special?)
    # @!method rdev
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_rdev

    # @!method rdev=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_rdev, name: 'rdev='

    # @!method rdevmajor
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_rdevmajor

    # @!method rdevmajor=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_rdevmajor, name: 'rdevmajor='

    # @!method rdevminor
    #   @return [Integer] :dev_t
    attach_attribute :archive_entry_rdevminor

    # @!method rdevminor=(dev)
    #   @param [Integer] dev
    attach_attribute :archive_entry_set_rdevminor, name: 'rdevminor='
    # endregion

    # region File size

    # @!method size
    #   @return [Integer] :int64_t
    attach_attribute :archive_entry_size

    # @!method size=(size)
    #   @param [Integer] size
    attach_attribute :archive_entry_set_size, name: 'size='

    # @!method size_is_set?
    #   @return [Boolean]
    attach_attribute :archive_entry_size_is_set, post: proc_is_nonzero

    # @!method unset_size
    attach_attribute :archive_entry_unset_size

    # endregion

    # @!method sourcepath
    #   @return [String]
    attach_attribute :archive_entry_sourcepath

    # @!method copy_sourcepath(path)
    #   @param [String] path
    attach_attribute :archive_entry_copy_sourcepath

    alias sourcepath= copy_sourcepath

    # region Ownership
    # @!method uid
    #   @return [Integer] :int64_t
    attach_attribute :archive_entry_uid

    # @!method uid=(uid)
    #   @param [Integer] uid
    attach_attribute :archive_entry_set_uid, name: 'uid='

    # @!method uname
    #   @return [String]
    attach_attribute :archive_entry_uname

    # @!method uname=(uname)
    #   @param [String] uname
    attach_attribute :archive_entry_set_uname, name: 'uname='

    # @!method copy_uname(uname)
    #   @param [String] uname
    attach_attribute :archive_entry_copy_uname
    # endregion

    # region Extended attributes

    # @param [String] name
    # @param [String] value
    def xattr_add_entry(name, value)
      raise ArgumentError, 'value is not a String' unless value.is_a?(String)

      C.archive_entry_xattr_add_entry(entry, name, Utils.get_memory_ptr(value), value.bytesize)
    end

    # @!method xattr_clear
    attach_attribute :archive_entry_xattr_clear

    # @!method xattr_count
    #   @return [Integer]
    attach_attribute :archive_entry_xattr_count

    # @return [Array<String>] of [:name, :value]
    def xattr_next
      name  = FFI::MemoryPointer.new :pointer
      value = FFI::MemoryPointer.new :pointer
      size  = FFI::MemoryPointer.new :size_t
      return nil if C.archive_entry_xattr_next(entry, name, value, size) != C::OK

      name  = name.get_pointer(0) unless name.null?
      value = value.get_pointer(0) unless value.null?
      # Someday size.get(:size_t) could work
      [
        name.null? ? nil : name.get_string(0),
        value.null? ? nil : value.get_bytes(0, size.send("get_uint#{FFI.type_size(:size_t) * 8}", 0))
      ]
    end

    # @!method xattr_reset
    #   @return [Integer]
    attach_attribute :archive_entry_xattr_reset

    # endregion
  end
end
