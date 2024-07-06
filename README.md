# chess_swift
Minimal chess, in Swift

This is a bare-bones computer-chess player for the terminal, in about 500 lines of code. It doesn't know castling, promotion, or en passant, or do any sort of optimization.

```
    a  b  c  d  e  f  g  h
8: {R}{N} ·  -  ·  - {N}{R}
7: {P} ·  -  ·  - {P}{P}{P}
6: {P} -  ·  -  ·  -  ·  - 
5:  -  ·  -  ·  -  ·  -  · 
4:  K  -  ·  - {P} -  · {Q}
3:  -  ·  - {K} -  ·  -  · 
2:  ·  -  ·  -  R  -  ·  - 
1:  -  ·  -  ·  -  ·  -  · 

Your move: e2 g2

    a  b  c  d  e  f  g  h
8: {R}{N} ·  -  ·  - {N}{R}
7: {P} ·  -  ·  - {P}{P}{P}
6: {P} -  ·  -  ·  -  ·  - 
5:  -  ·  -  ·  -  ·  -  · 
4:  K  -  ·  - {P} -  · {Q}
3:  -  ·  - {K} -  ·  -  · 
2:  ·  -  ·  -  ·  -  R  - 
1:  -  ·  -  ·  -  ·  -  · 

best move: {P} e4 e3 -0.14;  K  a4 b3 0.82; {K} d3 e4 -0.47; 

    a  b  c  d  e  f  g  h
8: {R}{N} ·  -  ·  - {N}{R}
7: {P} ·  -  ·  - {P}{P}{P}
6: {P} -  ·  -  ·  -  ·  - 
5:  -  ·  -  ·  -  ·  -  · 
4:  K  -  ·  -  ·  -  · {Q}
3:  -  ·  - {K}{P} ·  -  · 
2:  ·  -  ·  -  ·  -  R  - 
1:  -  ·  -  ·  -  ·  -  · 
      Check!

Your move:
```
