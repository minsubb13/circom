# [zk-SNARK] Groth16 (1) - QAP

Groth16은 zk-SNARK의 대표적인 프로토콜이다. 이 시리즈에서는 Groth16의 동작 과정을 이론으로 이해해보고 circom과 snarkjs로 실습해보는 과정을 기록해보려고 한다. zk-SNARK에 대한 기본적인 개념을 알고 있다는 전제 하에 해당 프로토콜이 실제로 어떻게 작동하는지 설명해보고자 한다.

> (동작 과정에 집중해서 서술하다보니 엄밀하고 정확한 용어나 설명이 누락될 수 있습니다. 지적해주시면 보충해서 수정하겠습니다)
> 

Groth16의 동작 과정을 크게 front-end, back-end로 나누자면,

- Front-end: algebraic circuit을 QAP로 변환하는 다항식 변환 과정
- 변환한 QAP를 prover가 증명하고 verifier가 검증하는 과정

으로 나눌 수 있다.

이 포스트에서는 비탈릭 부테린의 블로그 글 “Quadratic Arithmetic Programs: from Zero to Hero”를 바탕으로 Groth16의 front-end 파트를 설명해본다. 해당 글을 먼저 읽어보는 것을 추천한다.

# 문제 정의

증명하고자 하는 computational problem은 다음과 같다.

**“$x^3 + x + 5 = 35$를 만족하는 $x$를 알고 있음을 $x$를 밝히지 않고 증명하고 싶다.”**

```bash
def qeval(x):
    y = x**3
    return x + y + 5
```

힌트를 주자면 $x=3$이다. 하지만 prover는 이 해답을 직접 밝히지 않으면서도 해답을 알고 있다는 것을 증명하고 싶다. 이것이 바로 zero-knowledge의 핵심이다.

그렇다면 어떻게 답을 알려주지 않으면서 "답을 알고 있다"는 사실만 증명할 수 있을까? 첫 번째 단계는 이 문제를 **algebraic circuit**으로 변환하는 것이다.

# Flattening

위의 코드를 statements와 expressions로 표현하는 과정을 flattening이라고 한다. Flattening의 목표는 $x = y \star z$로 표현하는 것이다. 이때 operation은 +, -, *, / 가 될 수 있다. Flattening을 통해 문제를 arithmetic circuit으로 변환한다. 여기서의 목표는 모든 연산을 $x = y \star z$ 형태로 표현하는 것이다. 이때 $\star$ 는 기본 연산(+, -, *, /)이 될 수 있다.

```bash
sym_1 = x * x
y = sym_1 * x
sym_2 = y + x
~out = sym_2 + 5
```

각 줄은 하나의 제약(constraint)을 나타낸다. 편의상 첫 번째 줄을 $z=1$, 두 번째 줄을 $z=2$... 이라고 하자. 이제 우리는 4개의 제약을 가진 arithmetic circuit을 얻었다.

# R1CS

이제 위의 arithmetic circuit을 Rank-1 Constraint System (R1CS)으로 변환해야 한다. R1CS는 다음 형태의 방정식들로 이루어진 시스템이다

$$
s \cdot a \times s \cdot b - s \cdot c = 0
$$

여기서 $\cdot$은 선형대수의 내적(dot product)이고, $s$를 witness라고 하는데, 모든 private, public input과 중간 변수 값을 포함하는 벡터이다. Public input에는 모두가 알 수 있는 값 (출력값 35가 있다), Private input에서는 prover만 아는 값 ($x=3$), 중간 변수는 sym_1, y, sym_2가 된다.

따라서 위의 arithmetic circuit의 witness vector $s$는 `s = [one, x, ~out, sym_1, y, sym_2]` 가 된다. one은 상수항을 나타낸다. Prover가 알고 있는 $s$는 `[1, 3, 35, 9, 27, 30]` 이다.

# Gates to R1CS

첫 번째 제약 `(sym_1 = x * x)`의 경우를 예시로 R1CS를 변환해보자.

이 제약을 $a \star b = c$ 형태로 표현하면

```bash
s = [one, x, ~out, sym_1, y, sym_2]

a = [0, 1, 0, 0, 0, 0] // x
b = [0, 1, 0, 0, 0, 0] // x
c = [0, 0, 0, 1, 0, 0] // sym_1
```

각 벡터는 $s$의 어느 원소를 선택할지를 나타낸다. $s\cdot a \times s\cdot b - s\cdot c=0$ 으로 검증해보자면, $(0×1+1×3+...)×(0×1+1×3+...)=3×3=9=sym_1$이므로, $z=1$의 제약 사항을 만족한다.

, $x * 1 + x * 1 - sym\_1 = 0$ 이므로, $z=1$의 제약사항을 만족한다. 따라서 R1CS로의 변환은 constraint를 선형 결합으로 표현하는 것이라고 할 수 있다.

$$
\{s \cdot
\begin{pmatrix}
0 \\ 1 \\ 0 \\ 0 \\ 0 \\ 0 
\end{pmatrix}

\}*\{
s \cdot
\begin{pmatrix}
0 \\ 1 \\ 0 \\ 0 \\ 0 \\ 0 
\end{pmatrix}
\} = 
\{s \cdot \begin{pmatrix}
0 \\ 0 \\ 0 \\ 1 \\ 0 \\ 0
\end{pmatrix}\}
$$

같은 방식으로 나머지 3개의 제약에 대해서도 다음과 같이 나타낼 수 있다.

```bash
(z = 2)
a = [0, 0, 0, 1, 0, 0]
b = [0, 1, 0, 0, 0, 0]
c = [0, 0, 0, 0, 1, 0]

(z = 3)
a = [0, 1, 0, 0, 1, 0]
b = [1, 0, 0, 0, 0, 0]
c = [0, 0, 0, 0, 0, 1]

(z = 4)
a = [5, 0, 0, 0, 0, 1]
b = [1, 0, 0, 0, 0, 0]
c = [0, 0, 1, 0, 0, 0]
```

이제, 모든 constraint의 a, b, c를 모아서 행렬 A, B, C를 만들 수 있다.

```bash
A = [0, 1, 0, 0, 0, 0]
    [0, 0, 0, 1, 0, 0]
    [0, 1, 0, 0, 1, 0]
    [5, 0, 0, 0, 0, 1]

B = [0, 1, 0, 0, 0, 0]
    [0, 1, 0, 0, 0, 0]
    [1, 0, 0, 0, 0, 0]
    [1, 0, 0, 0, 0, 0]

C = [0, 0, 0, 1, 0, 0]
    [0, 0, 0, 0, 1, 0]
    [0, 0, 0, 0, 0, 1]
    [0, 0, 1, 0, 0, 0]
```

각 행은 하나의 제약을 나타낸다. 다시 검증해보면, $s\cdot A + s \cdot B - s \cdot C = 0$이 됨을 알 수 있다.

# R1CS to QAP

위에서 확인한 대로, 각각의 제약을 $s\cdot A + s \cdot B - s \cdot C = 0$ 으로 나타낼 수 있다. 이를 다시 풀어쓰면

$$
a_1 = [0, 1, 0, 0, 0, 0]\\
a_2 = [0, 0, 0, 1, 0, 0]\\
a_3 = [0, 1, 0, 0, 1, 0]\\
a_4 = [5, 0, 0, 0, 0, 1]\\

s \cdot a_1 \times s \cdot b_1 - s \cdot c_1 = 0\\
s \cdot a_2 \times s \cdot b_2 - s \cdot c_2 = 0\\
s \cdot a_3 \times s \cdot b_3 - s \cdot c_3 = 0\\
s \cdot a_4 \times s \cdot b_4 - s \cdot c_4 = 0
$$

따라서 증명 벡터 $s$가 유효하다면 위의 방정식을 모두 만족해야한다.

이것을 일반화 한다면, m개의 constraint에 대해 R1CS를 다음과 같이 나타낼 수 있다.

$$
s \cdot a_1 \times s \cdot b_1 - s \cdot c_1 = 0\\
s \cdot a_2 \times s \cdot b_2 - s \cdot c_2 = 0\\
\cdots \\
s \cdot a_m \times s \cdot b_m - s \cdot c_m = 0\\
$$

Prover의 목표는 s의 값이 무엇인지 알고 있음을 증명하는 것이다. R1CS로도 위의 문제를 손쉽게 표현할 수 있지만, 문제는 일반화의 경우와 같이 circuit의 constraint의 개수가 많아질 때다. constraint의 개수가 많아질수록 verifier가 모든 제약을 확인해야하고 이는 검증 시간이 늘어난다. 이를 위해 이 제약을 제약의 개수와 상관없이 한 번의 연산으로 검증할 수 있는 단일 방정식으로 바꾸는 것이 QAP이다.

여러 제약을 하나로 합칠 때 Lagrange Interpolation을 사용한다. 기본 아이디어는 고등학교 수학에서 배운 바와 같다. n개의 점 $(x_0, y_0), (x_1, y_1), \cdots, (x_{n-1}, y_{n-1})$가 주어진다면 이 모든 점을 지나는 $n-1$차 다항식이 유일하게 한 개 존재한다는 아이디어다. 고등학교 수학에서 최고차항의 계수가 3인 다항 함수가 $x=1,2,3$에서 해를 가진다면 $f(x) = a(x-1)(x-2)(x-3)$으로 나타내는 것과 동일한 원리이다.

이것을 일반화하면, 점 점 $(x_1, y_1), (x_2, y_2), ..., (x_n, y_n)$을 지나는 다항식 $L(x)$는 다음과 같이 나타낼 수 있다.

$$
L(x) = \sum_{i=1}^{n} y_i \prod_{j=1, j \neq i}^{n} \frac{x - x_j}{x_i - x_j}
$$

복잡해 보이지만, 예시를 통해 이해해보자.

A 행렬을 다시 보자.

```cpp
A = [0, 1, 0, 0, 0, 0]
    [0, 0, 0, 1, 0, 0]
    [0, 1, 0, 0, 1, 0]
    [5, 0, 0, 0, 0, 1]
```

이때, 행렬 A의 첫 번째 열 $A_1$은 `[0, 0, 0, 5]` 이다. 이는 다음 4개의 점을 의미한다

```bash
(1, 0) - 제약 1에서 'one'의 계수 0
(2, 0) - 제약 2에서 'one'의 계수 0
(3, 0) - 제약 3에서 'one'의 계수 0
(4, 5) - 제약 4에서 'one'의 계수 5
```

이 4개의 점을 지나는 3차 다항식 $A_1(x)$를 Lagrange Interpolation으로 구하면

$$
A_1(x) = 0 \cdot \frac{(x-2)(x-3)(x-4)}{(1-2)(1-3)(1-4)} + 0 \cdot \frac{(x-1)(x-3)(x-4)}{(2-1)(2-3)(2-4)}\\
+ 0 \cdot \frac{(x-1)(x-2)(x-4)}{(3-1)(3-2)(3-4)} + 5 \cdot \frac{(x-1)(x-2)(x-3)}{(4-1)(4-2)(4-3)} \\
= 5 \cdot \frac{(x-1)(x-2)(x-3)}{6}
$$

$$
A_1(x) = 5 \cdot \frac{x^3 - 6x^2 + 11x - 6}{6} = \frac{5}{6}x^3 - 5x^2 + \frac{55}{6}x - 5
$$

이것을 계수 형태로 표현한 것이 `[-5.0, 9.166, -5.0, 0.833]` 이다.

이런 식으로 A, B, C 모든 행렬에 Lagrange Interpolation를 적용한 결과는 다음과 같다.

```cpp
A polynomials
[-5.0, 9.166, -5.0, 0.833]
[8.0, -11.333, 5.0, -0.666]
[0.0, 0.0, 0.0, 0.0]
[-6.0, 9.5, -4.0, 0.5]
[4.0, -7.0, 3.5, -0.5]
[-1.0, 1.833, -1.0, 0.166]

B polynomials
[3.0, -5.166, 2.5, -0.333]
[-2.0, 5.166, -2.5, 0.333]
[0.0, 0.0, 0.0, 0.0]
[0.0, 0.0, 0.0, 0.0]
[0.0, 0.0, 0.0, 0.0]
[0.0, 0.0, 0.0, 0.0]

C polynomials
[0.0, 0.0, 0.0, 0.0]
[0.0, 0.0, 0.0, 0.0]
[-1.0, 1.833, -1.0, 0.166]
[4.0, -4.333, 1.5, -0.166]
[-6.0, 9.5, -4.0, 0.5]
[4.0, -7.0, 3.5, -0.5]
```

이제 $s = [1, 3, 35, 9, 27, 30]$을 이용해서 최종 다항식을 만들 수 있다.

$$
A(x) = s_1 \cdot A_1(x) + s_2 \cdot A_2(x) + \cdots + s_6 \cdot A_6(x)\\
B(x) = s_1 \cdot B_1(x) + s_2 \cdot B_2(x) + \cdots + s_6 \cdot B_6(x)\\
C(x) = s_1 \cdot C_1(x) + s_2 \cdot C_2(x) + \cdots + s_6 \cdot C_6(x)
$$

실제로 이것을 계산해보면 다음과 같다.

$$
A(x) = s_1 \cdot A_1(x) + s_2 \cdot A_2(x) + \cdots + s_6 \cdot A_6(x)\\
= 1 \cdot A_1(x) + 3 \cdot A_2(x) + 35 \cdot A_3(x) + 9 \cdot A_4(x) + 27 \cdot A_5(x) + 30 \cdot A_6(x)\\
\cdots
$$

$$
A(x) = 43 - 73.333x + 38.5x^2 - 5.166x^3\\
B(x) = -3 + 10.333x - 5x^2 + 0.666x^3\\
C(x) = -41 + 71.666x - 24.5x^2 + 2.833x^3
$$

이제 R1CS의 4개의 constraint는 다음 4개의 polynomial constraint와 동일하다.

$$
A(1)\cdot B(1) - C(1) = 0\\
A(2)\cdot B(2) - C(2) = 0\\
A(3)\cdot B(3) - C(3) = 0\\
A(4)\cdot B(4) - C(4) = 0\\
$$

이는 제약 $z$에 대하여 $P(z) = A(z) \cdot B(z) - C(z)$라는 새로운 다항식이 $z = 1, 2, 3, 4$를 해로 가져야 한다는 것을 의미한다. 따라서, 나눗셈 정리에 따라 $T(z)$가 $z=1,2,3,4$를 해로 가진다면 $T(z)$는 반드시 $(z-1)(z-2)(z-3)(z-4)$로 나누어떨어져야 한다.

이때, $T(z) = (x-1)(x-2)(x-3)(x-4)$를 Target polynomial이라고 한다.

결국 prover가 올바른 witness $s$를 알고 있다면, 다음이 성립한다.

$$
P(z) = A(z) \cdot B(z) - C(z)= H(z)\cdot T(z)
$$

이때, $H(z)$가 존재한다는 것이 QAP의 핵심이다.

다음 글에서는 prover가 이것을 어떻게 이용하여 verifier에게 증명하는지에 대해 살펴보겠다.