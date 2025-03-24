# Компилятор и флаги
CXX = g++
ASM = nasm
 CXXFLAGS = -Wall -Wextra -std=c++17
ASMFLAGS = -f elf64
LDFLAGS = -no-pie -lstdc++

# Исходные файлы
SRC_CPP = my_prog.cpp
SRC_ASM = asm_printf.asm

# Объектные файлы
OBJ_CPP = $(SRC_CPP:.cpp=.o)
OBJ_ASM = $(SRC_ASM:.asm=.o)

# Итоговый исполняемый файл
TARGET = test

# Правило по умолчанию
all: $(TARGET)

# Сборка исполняемого файла
$(TARGET): $(OBJ_CPP) $(OBJ_ASM)
	$(CXX) $(LDFLAGS) -o $@ $^

# Компиляция .cpp файлов
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Компиляция .asm файлов
%.o: %.asm
	$(ASM) $(ASMFLAGS) $< -o $@

# Очистка
clean:
	rm -f $(OBJ_CPP) $(OBJ_ASM) $(TARGET)
