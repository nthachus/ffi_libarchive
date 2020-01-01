# frozen_string_literal: true

require 'ffi-inliner'

module Archive
  module Stat
    extend Inliner

    inline do |builder|
      builder.include 'stdlib.h'
      builder.include 'sys/types.h'
      builder.include 'sys/stat.h'
      builder.include 'string.h'
      builder.include 'errno.h'

      builder.c <<-CODE
        void* ffi_libarchive_create_stat(const char* filename) {
          struct stat* s = malloc(sizeof(struct stat));
          if (stat(filename, s) != 0) return NULL;
          return s;
        }
      CODE

      builder.c <<-CODE
        void* ffi_libarchive_create_lstat(const char* filename) {
          struct stat* s = malloc(sizeof(struct stat));
          if (lstat(filename, s) != 0) return NULL;
          return s;
        }
      CODE

      builder.c <<-CODE
        void ffi_libarchive_free_stat(void* s) {
          free(s);
        }
      CODE

      builder.c <<-CODE
        const char* ffi_error() {
          return strerror(errno);
        }
      CODE
    end
  end
end
