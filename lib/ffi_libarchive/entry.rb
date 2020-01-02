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
    # endregion

    # @param [Pointer]
    # @return [Entry]
    def self.from_pointer(entry)
      new entry
    end

    # @param [Pointer] entry
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

    # @return [Pointer]
    attr_reader :entry

    def atime
      Time.at C.archive_entry_atime(entry)
    end

    def atime=(time)
      set_atime time, 0
    end

    def set_atime(time, nsec)
      C.archive_entry_set_atime(entry, time.to_i, nsec)
    end

    def atime_is_set?
      C.archive_entry_atime_is_set(entry) != 0
    end

    def atime_nsec
      C.archive_entry_atime_nsec(entry)
    end

    def birthtime
      Time.at C.archive_entry_birthtime(entry)
    end

    def birthtime=(time)
      set_birthtime time, 0
    end

    def set_birthtime(time, nsec)
      C.archive_entry_set_birthtime(entry, time.to_i, nsec)
    end

    def birthtime_is_set?
      C.archive_entry_birthtime_is_set(entry) != 0
    end

    def birthtime_nsec
      C.archive_entry_birthtime_nsec(entry)
    end

    def ctime
      Time.at C.archive_entry_ctime(entry)
    end

    def ctime=(time)
      set_ctime time, 0
    end

    def set_ctime(time, nsec)
      C.archive_entry_set_ctime(entry, time.to_i, nsec)
    end

    def ctime_is_set?
      C.archive_entry_ctime_is_set(entry) != 0
    end

    def ctime_nsec
      C.archive_entry_ctime_nsec(entry)
    end

    def block_device?
      filetype & S_IFMT == S_IFBLK
    end

    def character_device?
      filetype & S_IFMT == S_IFCHR
    end

    def directory?
      filetype & S_IFMT == S_IFDIR
    end

    def fifo?
      filetype & S_IFMT == S_IFIFO
    end

    def regular?
      filetype & S_IFMT == S_IFREG
    end

    alias file? regular?

    def socket?
      filetype & S_IFMT == S_IFSOCK
    end

    def symbolic_link?
      filetype & S_IFMT == S_IFLNK
    end

    def copy_fflags_text(fflags_text)
      C.archive_entry_copy_fflags_text(entry, fflags_text)
      nil
    end

    def copy_gname(gname)
      C.archive_entry_copy_gname(entry, gname)
      nil
    end

    def copy_hardlink(lnk)
      C.archive_entry_copy_hardlink(entry, lnk)
      nil
    end

    def copy_link(lnk)
      C.archive_entry_copy_link(entry, lnk)
      nil
    end

    def copy_lstat(filename)
      # TODO: get this work without ffi-inliner
      begin
        require 'ffi_libarchive/stat'
      rescue StandardError => e
        raise "ffi-inliner build for copy_stat failed:\n#{e}"
      end

      stat = Archive::Stat.ffi_libarchive_create_lstat(filename)
      raise Error, "Copy stat failed: #{Archive::Stat.ffi_error}" if stat.null?

      begin
        C.archive_entry_copy_stat(entry, stat)
      ensure
        Archive::Stat.ffi_libarchive_free_stat(stat)
      end
    end

    def copy_pathname(file_name)
      C.archive_entry_copy_pathname(entry, file_name)
      nil
    end

    def copy_sourcepath(path)
      C.archive_entry_copy_sourcepath(entry, path)
      nil
    end

    def copy_stat(filename)
      # TODO: get this work without ffi-inliner
      begin
        require 'ffi_libarchive/stat'
      rescue StandardError => e
        raise "ffi-inliner build for copy_stat failed:\n#{e}"
      end

      stat = Archive::Stat.ffi_libarchive_create_stat(filename)
      raise Error, "Copy stat failed: #{Archive::Stat.ffi_error}" if stat.null?

      begin
        C.archive_entry_copy_stat(entry, stat)
      ensure
        Archive::Stat.ffi_libarchive_free_stat(stat)
      end
    end

    def copy_symlink(slnk)
      C.archive_entry_copy_symlink(entry, slnk)
      nil
    end

    def copy_uname(uname)
      C.archive_entry_copy_uname(entry, uname)
      nil
    end

    def dev
      C.archive_entry_dev(entry)
    end

    def dev=(dev)
      C.archive_entry_set_dev(entry, dev)
    end

    def devmajor
      C.archive_entry_devmajor(entry)
    end

    def devmajor=(dev)
      C.archive_entry_set_devmajor(entry, dev)
    end

    def devminor
      C.archive_entry_devminor(entry)
    end

    def devminor=(dev)
      C.archive_entry_set_devminor(entry, dev)
    end

    def fflags
      set = FFI::MemoryPointer.new :long
      clear = FFI::MemoryPointer.new :long
      C.archive_entry_fflags(entry, set, clear)

      [set.read(:long), clear.read(:long)]
    end

    def fflags_text
      C.archive_entry_fflags_text(entry)
    end

    def filetype
      C.archive_entry_filetype(entry)
    end

    def filetype=(type)
      type = self.class.const_get(type.to_s.upcase) unless type.is_a?(Integer)
      C.archive_entry_set_filetype(entry, type)
    end

    def gid
      C.archive_entry_gid(entry)
    end

    def gid=(gid)
      C.archive_entry_set_gid(entry, gid)
    end

    def gname
      C.archive_entry_gname(entry)
    end

    def gname=(gname)
      C.archive_entry_set_gname(entry, gname)
    end

    def hardlink
      C.archive_entry_hardlink(entry)
    end

    def hardlink=(lnk)
      C.archive_entry_set_hardlink(entry, lnk)
    end

    def ino
      C.archive_entry_ino(entry)
    end

    def ino=(ino)
      C.archive_entry_set_ino(entry, ino)
    end

    def link=(lnk)
      C.archive_entry_set_link(entry, lnk)
    end

    def mode
      C.archive_entry_mode(entry)
    end

    def mode=(mode)
      C.archive_entry_set_mode(entry, mode)
    end

    def mtime
      Time.at C.archive_entry_mtime(entry)
    end

    def mtime=(time)
      set_mtime time, 0
    end

    def set_mtime(time, nsec)
      C.archive_entry_set_mtime(entry, time.to_i, nsec)
    end

    def mtime_is_set?
      C.archive_entry_mtime_is_set(entry) != 0
    end

    def mtime_nsec
      C.archive_entry_mtime_nsec(entry)
    end

    def nlink
      C.archive_entry_nlink(entry)
    end

    def nlink=(nlink)
      C.archive_entry_set_nlink(entry, nlink)
    end

    def pathname
      C.archive_entry_pathname(entry)
    end

    def pathname=(path)
      C.archive_entry_set_pathname(entry, path)
    end

    def perm=(perm)
      C.archive_entry_set_perm(entry, perm)
    end

    def rdev
      C.archive_entry_rdev(entry)
    end

    def rdev=(dev)
      C.archive_entry_set_rdev(entry, dev)
    end

    def rdevmajor
      C.archive_entry_rdevmajor(entry)
    end

    def rdevmajor=(dev)
      C.archive_entry_set_rdevmajor(entry, dev)
    end

    def rdevminor
      C.archive_entry_rdevminor(entry)
    end

    def rdevminor=(dev)
      C.archive_entry_set_rdevminor(entry, dev)
    end

    def set_fflags(set, clear)
      C.archive_entry_set_fflags(entry, set, clear)
    end

    def size
      C.archive_entry_size(entry)
    end

    def size=(size)
      C.archive_entry_set_size(entry, size)
    end

    def size_is_set?
      C.archive_entry_size_is_set(entry) != 0
    end

    def sourcepath
      C.archive_entry_sourcepath(entry)
    end

    def strmode
      C.archive_entry_strmode(entry)
    end

    def symlink
      C.archive_entry_symlink(entry)
    end

    def symlink=(slnk)
      C.archive_entry_set_symlink(entry, slnk)
    end

    def uid
      C.archive_entry_uid(entry)
    end

    def uid=(uid)
      C.archive_entry_set_uid(entry, uid)
    end

    def uname
      C.archive_entry_uname(entry)
    end

    def uname=(uname)
      C.archive_entry_set_uname(entry, uname)
    end

    def unset_atime
      C.archive_entry_unset_atime(entry)
    end

    def unset_birthtime
      C.archive_entry_unset_birthtime(entry)
    end

    def unset_ctime
      C.archive_entry_unset_ctime(entry)
    end

    def unset_mtime
      C.archive_entry_unset_mtime(entry)
    end

    def unset_size
      C.archive_entry_unset_size(entry)
    end

    def xattr_add_entry(name, value)
      C.archive_entry_xattr_add_entry(entry, name, value, value.size)
    end

    def xattr_clear
      C.archive_entry_xattr_clear(entry)
    end

    def xattr_count
      C.archive_entry_xattr_count(entry)
    end

    def xattr_next
      name = FFI::MemoryPointer.new :pointer
      value = FFI::MemoryPointer.new :pointer
      size = FFI::MemoryPointer.new :size_t
      return nil if C.archive_entry_xattr_next(entry, name, value, size) != C::OK

      # TODO: sometimes size.read(:size_t) could work
      value_str =
        if value.null?
          nil
        elsif size.null?
          value.read_string_to_null
        else
          value.read_string_length(size.read(:size_t))
        end

      [name.null? ? nil : name.read_string_to_null, value_str]
    end

    def xattr_reset
      C.archive_entry_xattr_reset(entry)
    end
  end
end
