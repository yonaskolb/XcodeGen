@main
public struct spm_project {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(spm_project().text)
    }
}
