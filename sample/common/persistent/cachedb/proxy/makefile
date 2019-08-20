objs = libsql_split.o sql-tokenizer.o glib-ext.o glib-ext-ref.o sql-tokenizer-tokens.o sql-tokenizer-keywords.o proxy_parse.o
#CC = gcc
CC = g++
CC_FLAG = -D_NOMNG -D_FILELINE

INC = -I ./ -I /usr/local/include/glib-2.0/ -I /usr/local/lib/glib-2.0/include/ 
LIB = -l glib-2.0 -L /usr/share/

libsql_split.so : ${objs}
	${CC} ${CC_FLAG} ${objs} ${LIB} -shared -fPIC -Wall -O2  -o libsql_split.so 
	rm -rf *.o

.SUFFIXES: .c .o .cpp .l
.c.o:
	gcc ${INC} -std=c99 -Wall -O2 -c $*.c -o $*.o -shared -fPIC
.cpp.o:
	${CC} ${INC} -Wall -O2 -c $*.cpp -o $*.o -shared -fPIC

clean:
	rm -rf *.so *.o
