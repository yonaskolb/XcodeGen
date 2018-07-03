class Xcodegen < Formula
  desc "Tool that generates your Xcode project from a project spec"
  homepage "https://github.com/yonaskolb/XcodeGen"
  url "https://github.com/yonaskolb/XcodeGen/archive/1.10.0.tar.gz"
  sha256 "afc0a893709edb9386c67a633f5d28a1fa3d0d518cbb26a99db3e5056d09976c"
  head "https://github.com/yonaskolb/XcodeGen.git"

  depends_on :xcode

  def install
    
    # fixes an issue an issue in homebrew when both Xcode 9.3+ and command line tools are installed
    # see more details here https://github.com/Homebrew/brew/pull/4147
    # remove this once homebrew is patched
    ENV["CC"] = Utils.popen_read("xcrun -find clang").chomp

    # step 2: usual build
    system "make", "install", "PREFIX=#{prefix}"
  end

  test do
    (testpath/"xcodegen.yml").write <<-EOS.undent
      name: GeneratedProject
      targets:
        TestProject:
          type: application
          platform: iOS
          sources: TestProject
          settings:
            PRODUCT_BUNDLE_IDENTIFIER: com.test
            PRODUCT_NAME: TestProject
    EOS
    Dir.mkdir(File.join(testpath, "TestProject"))
    system("#{bin}/XcodeGen --spec #{File.join(testpath, "xcodegen.yml")}")
    system("xcodebuild --project #{File.join(testpath, "GeneratedProject.xcodeproj")}")
  end
end
