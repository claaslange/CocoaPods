module Pod
  module Downloader
    class Cleaner
      attr_reader :root
      attr_reader :specs_by_platform

      def initialize(root, specs_by_platform)
        @root = root
        @specs_by_platform = specs_by_platform
      end

      # Removes all the files not needed for the installation according to the
      # specs by platform.
      #
      # @return [void]
      #
      def clean!
        clean_paths.each { |path| FileUtils.rm_rf(path) } if root.exist?
      end

      private

      # @return [Array<Sandbox::FileAccessor>] the file accessors for all the
      #         specifications on their respective platform.
      #
      def file_accessors
        return @file_accessors if @file_accessors
        @file_accessors = []
        specs_by_platform.each do |platform, specs|
          specs.each do |spec|
            @file_accessors << Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
          end
        end
        @file_accessors
      end

      # @return [Sandbox::PathList] The path list for this Pod.
      #
      def path_list
        @path_list ||= Sandbox::PathList.new(root)
      end

      # Finds the absolute paths, including hidden ones, of the files
      # that are not used by the pod and thus can be safely deleted.
      #
      # @note   Implementation detail: Don't use `Dir#glob` as there is an
      #         unexplained issue (#568, #572 and #602).
      #
      # @todo   The paths are down-cased for the comparison as issues similar
      #         to #602 lead the files not being matched and so cleaning all
      #         the files. This solution might create side effects.
      #
      # @return [Array<Strings>] The paths that can be deleted.
      #
      def clean_paths
        cached_used = used_files
        glob_options = File::FNM_DOTMATCH | File::FNM_CASEFOLD
        files = Pathname.glob(root + '**/*', glob_options).map(&:to_s)

        files.reject! do |candidate|
          candidate = candidate.downcase
          candidate.end_with?('.', '..') || cached_used.any? do |path|
            path = path.downcase
            path.include?(candidate) || candidate.include?(path)
          end
        end
        files
      end

      # @return [Array<String>] The absolute path of all the files used by the
      #         specifications (according to their platform) of this Pod.
      #
      def used_files
        files = [
          file_accessors.map(&:vendored_frameworks),
          file_accessors.map(&:vendored_libraries),
          file_accessors.map(&:resource_bundle_files),
          file_accessors.map(&:license),
          file_accessors.map(&:prefix_header),
          file_accessors.map(&:preserve_paths),
          file_accessors.map(&:readme),
          file_accessors.map(&:resources),
          file_accessors.map(&:source_files),
        ]

        files.flatten.compact.map(&:to_s).uniq
      end
    end
  end
end
