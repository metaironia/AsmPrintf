extern "C" {
    int MyPrintf (const char *format, ...) __attribute__((format(printf, 1, 2)));     
}

int main (void) {

    MyPrintf ("%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b\n", -1, "love", 3802, 100, 33, 30, -1, "love", 3802, 100, 33, 30);

    return 0;
}