[CCode (cheader_filename = "QQwing-wrapper.h")]
namespace QQwing {
    [CCode (array_length = false)]
    int[] generate_puzzle (int difficulty);
    void print_stats ([CCode (array_length = false)] int[] initPuzzle);
}
