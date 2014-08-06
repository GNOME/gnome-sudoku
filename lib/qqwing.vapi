[CCode (cheader_filename = "qqwing-wrapper.h")]
namespace QQwing {
    [CCode (array_length=false)]
    int[] generate_puzzle (int difficulty);
    void print_stats ([CCode (array_length = false)] int[] puzzle);
    string get_version ();
}
