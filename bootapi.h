extern void bootcall(int opcode, u32 lba, char* buffer, u32 count);

int strlen(char*string){
    int i = 0;
    for(;string[i];i++);
    return i;
}

void print(char *string){
    bootcall(0,0, string,strlen(string));
}

void diskread(u32 lba, char* buffer, u32 count){
    bootcall(0x42, lba, buffer, count);
}

void diskwrite(u32 lba, char* buffer, u32 count){
    bootcall(0x43, lba, buffer, count);
}
