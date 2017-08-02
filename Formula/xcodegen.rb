class Xcodegen < Formula
  
  desc "XcodeGen is a command line tool that generates your Xcode project using your folder structure and a simple project spec."
  homepage "https://github.com/yonaskolb/XcodeGen"
  version "0.1"
  url "https://github.com/yonaskolb/XcodeGen/archive/0.1.tar.gz"
  sha256 "29338d4fb17160408fc781e01143b3eff3dc4dc8db8305ef04864dea9e11bb62"
  head "https://github.com/yonaskolb/XcodeGen.git"

  depends_on :xcode

  def install
    yaml_lib_path = ".build/release/libCYaml.dylib"
    xcodegen_path = ".build/release/XcodeGen"
    ohai "Building XcodeGen"
    system("swift build -c release -Xlinker -rpath -Xlinker @executable_path -Xswiftc -static-stdlib")
    odie "Error building XcodeGen" if $?.exitstatus != 0
    system("install_name_tool -change #{yaml_lib_path} #{frameworks}/libCYaml.dylib #{xcodegen_path}")
    odie "Error linking dependencies" if $?.exitstatus != 0
    frameworks.install yaml_lib_path
    bin.install xcodegen_path
  end

  test do
    output = `#{bin}/XcodeGen`
    assert !output.empty?, "Failed installing XcodeGen"
  end

end