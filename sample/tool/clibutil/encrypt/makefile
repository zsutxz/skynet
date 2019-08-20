objs = des_encrypt.o rijndael.o
CC = g++
LUA_INC = ../../../../skynet/3rd/lua
CC_FLAG = -D_NOMNG -D_FILELINE -I$(LUA_INC)

des_encrypt.so : ${objs}
	${CC} ${CC_FLAG} ${objs} -shared -Wall  -O2  -o des_encrypt.so 
	rm -rf *.o
	mv des_encrypt.so ../../../luaclib/

.SUFFIXES: .c .o .cpp .l
.c.o:
	gcc ${LUA_INC} -std=c99 -Wall -O2 -c $*.c -o $*.o -shared -fPIC
.cpp.o:
	${CC} ${LUA_INC} -Wall -O2 -c $*.cpp -o $*.o -shared -fPIC

clean:
	rm -rf *.so *.o
	rm -rf ../../../luaclib/des_encrypt.so
