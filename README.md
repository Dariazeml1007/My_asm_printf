# 🚀 Custom printf (x86-64 Assembly + C) | [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<div align="center">
  <img src="https://img.shields.io/badge/x86__64-ASM-6E4C13?logo=assemblyscript" alt="x86-64 ASM">
  <img src="https://img.shields.io/badge/C-17-A8B9CC?logo=c" alt="C17">
  <img src="https://img.shields.io/badge/System_V_ABI-FF6600" alt="System V ABI">
</div>

Реализация `printf` с поддержкой форматов `%o %x %b %d %s %c %%`, где ключевые функции реализованы  на ассемблере.

## 🔥 Особенности
- **Гибридная реализация**: интерфейс на C + ассемблерное ядро
- **Поддерживаемые форматы**:
  ```c
  %d - целые числа (10-ричные)
  %x - шестнадцатеричные
  %o - восьмеричные
  %b - двоичные
  %s - строки
  %c - символы
  %% - вывод %
