extern "C" {
    int MyPrintf (const char *format, ...);     
}

int main (void) {

    MyPrintf ("Hello world, ot");

    return 0;
}