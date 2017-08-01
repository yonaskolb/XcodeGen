class Xcodegen < Formula
  
  desc "XcodeGen is a command line tool that generates your Xcode project using your folder structure and a simple project spec."
  homepage "https://github.com/yonaskolb/XcodeGen"
  version "0.1.0"
  url "https://github.com/yonaskolb/XcodeGen/archive/a086d90b3fa53b84e682d46972accc95996a955a.zip"
  sha256 "2615589ceb74696ef8ea1b4e5ac27c4b7a90fe955d9578b6b372e8aed193487c"
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

end