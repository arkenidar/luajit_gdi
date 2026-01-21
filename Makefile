all: produce_executable execute_executable

produce_executable:
	gcc -o "gdi_draw" -g -Wall "gdi_draw.c" -mwindows -lgdi32

execute_executable:
	./gdi_draw
