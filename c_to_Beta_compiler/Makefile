CC = gcc
CFLAGS = -Wall -Wextra -g -Iinclude

FLEX = flex
BISON = bison

TARGET = betac

SRCS = src/*.c parser.tab.c lex.yy.c

all: parser.tab.c lex.yy.c $(TARGET)

parser.tab.c parser.tab.h: parser.y
	$(BISON) -d -v parser.y

lex.yy.c: lexer.l parser.tab.h
	$(FLEX) lexer.l

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) -o $(TARGET) -lfl

clean:
	rm -f $(TARGET) parser.tab.c parser.tab.h lex.yy.c parser.output