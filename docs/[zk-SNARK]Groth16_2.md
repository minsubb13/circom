# [zk-SNARK] Groth16 (2) - Prove and Verification

이전 포스트에서 computational problem → arithmetic circuit → R1CS → QAP로 변환하는 과정을 살펴보았다. 이번 포스트에서는 만들어진 QAP를 가지고 prover가 어떻게 증명을 제출하고, verifier가 이를 어떻게 검증하는지 자세히 살펴보려고 한다.

핵심 아이디어를 먼저 이야기하자면, prover는 자신이 정답을 알고 있다는 것을 정답 자체를 공개하지 않고 증명할 수 있어야 한다. 이를 위해 암호학적 기법들을 활용하는데, 그 시작점이 바로 Trusted Setup이다.

# 1. Trusted Setup

Prover가 증명을 만들기 전에, 먼저 Trusted Setup 단계를 거쳐야 한다. 이는 신뢰할 수 있는 여러 참여자들이 모여 암호학적으로 안전한 공개 파라미터(CRS, Common Reference String)를 생성하는 과정이다.

### 0. 초기 설정

먼저 pairing-friendly한 타원곡선을 선정한다. 대표적으로 BN254나 BLS12-381 같은 곡선들이 사용된다. 그리고 타원곡선 상의 generator 점 $G$와 QAP의 최대 차수 $d$ (이는 회로의 크기에 따라 결정됨)를 준비한다.

### **1.1 비밀값 생성**

첫 번째 참여자는 타원 곡선의 유한체 내에서 임의의 scalar를 선택한다. 이를 $s_0$라고 하자. 이 값은 공개되어서는 안된다.

### **1.2 CRS(Common Reference String) 생성**

비밀값 $s_0$와 $G$를 이용해 다음을 계산한다.

$$
\{s_0^0G,\ s_0^1G,\ s_0^2G, \cdots ,\ s_0^{d-1}G\}
$$

### **1.3 Toxic Waste 폐기**

첫 번째 참여자는 CRS를 생성한 직후 반드시 선택했던 $s_0$를 폐기한다. 이 값을 알면 누구나 가짜 증명을 만들 수 있기 때문이다. 이 비밀값을 Toxic Waste라고 부른다.

### 1.4 Multi-Party Computation (MPC)

이때, 참여자 모두는 이 과정을 수행하는데, 중요한 점은 CRS를 만들 때 이전 사람의 CRS 위에 다음 사람의 비밀값$s$를 누적해서 업데이트 한다는 점이다. 따라서 두 번째 참여자의 비밀값 $s_1$를 이용한 CRS 업데이트 부분에서 CRS는 다음과 같이 업데이트된다.

$$
\{s_1^0(s_0^0G),\ s_1^1(s_0^1G),\ s_1^2(s_0^2G), \cdots ,\ s_1^{d-1}(s_0^{d-1}G)\}\\
= \{{(s_0\cdot s_1)^0G, (s_0⋅s_1)^1G, (s_0⋅s_1)^2G,⋯, (s_0⋅s_1)^{d−1}G}\}
$$

이 과정을 모든 참여자가 반복 수행하고, 마지막 참여자의 결과가 최종 CRS가 된다. 이 과정을 Multi Party Computation (MPC)라고 한다.

$$
CRS = \{\tau^0 G,\ \tau^1 G,\ \tau^2 G, \cdots,\ \tau^{d-1}G\}
$$

이 과정의 장점은 참여자 모두가 자신의 비밀값을 공개해야 최종 비밀값 $\tau$를 알 수 있다는 점이다. 따라서 한 명이라도 자신의 비밀값을 공개하지 않는다면 DLP로 인해 안정성이 보장된다. 최종적으로 생성된 CRS는 공개되어 prover와 verifier 모두 사용할 수 있지만, $\tau$ 자체는 아무도 알 수 없다.

# 2. 증명 생성

Prover는 위의 식을 이용해서 증명을 생성한다. prover는 다음 식이 성립함을 증명하고 싶다.

$$
P(z) = A(z) \cdot B(z) - C(z)= H(z)\cdot T(z)
$$

### 2.1 다항식 계산

이전 포스트에서 설명한 QAP 변환 과정과 같이 prover는 $A(z), B(z), C(z)$를 계산해서 $H(z)$를 구한다.

$$
H(z) = \frac{A(z) \cdot B(z) - C(z)}{T(z)}
$$

비탈릭의 글에서도 언급이 되어 있지만 prover가 올바른 witness를 가지고 있다면, 이 나눗셈은 나머지 없이 정확히 떨어진다. 나머지가 생긴다면 증명이 실패한다.

### 2.2 다항식 암호화

현재 상황에서 Prover는 비밀값 $\tau$를 모른다. 하지만, trusted setup 과정에서 만든 CRS를 알고 있으므로, $G \cdot A(\tau), G \cdot B(\tau), G \cdot H(\tau)$를 알 수 있다.

구체적인 예시로 이해해보자.

1. $A(x) = c_0 + c_1x + c_2x^2 + c_3x^3$ 라고 하자.
2. $CRS = \tau^0 G,\ \tau^1 G,\ \tau^2 G, \cdots,\ \tau^{d-1}G$ 이다.
3. $G\cdot A(\tau) = c_0\cdot G + c_1\cdot \tau \cdot G + c_2 \cdot \tau^2 \cdot G + c_3 \cdot \tau^3 \cdot G$
4. 따라서 prover는 CRS에 $A(z), B(z), C(z), H(z)$등의 계수를 곱해서 $G \cdot A(\tau), G \cdot B(\tau), G \cdot H(\tau)$를 손쉽게 구할 수 있다.

이전 포스트에서 $A(x)$를 실제로 구했다. 이것을 이용해서 실제로 계산해보면 다음과 같다.

$$
A(x) = 43 - 73.333x + 38.5x^2 - 5.166x^3\\
G\cdot A(\tau) = 43 \cdot G + (-73.333)\cdot \tau \cdot G + (38.5)\cdot \tau^2 \cdot G + (-5.166)\cdot \tau^3 \cdot G
$$

이때, 이 계산은 Multi-Scalar Multiplication (MSM)으로 손쉽게 계산할 수 있다.

같은 방식으로 prover는 다음을 모두 계산한다.

- $[A] = G \cdot A(\tau)$
- $[B] = G \cdot B(\tau)$
- $[C] = G \cdot C(\tau)$
- $[H] = G \cdot H(\tau)$

### 2.3 증명 제출

이렇게 계산한 암호화 값들, $[A], [B], [H]$을 증명으로 만들어 verifier에게 전달한다. 검증자는 이 값만을 이용해 쉽게 검증할 수 있다.

# 3. 증명 검증

Verifier는 prover에게 받은 정보를 pairing을 통해 쉽게 검증할 수 있다. 하지만 pairing은 타원곡선 암호의 개념 중에서도 매우 어려운 개념이라 간단하게 속성만 이해해보자.

### 3.1 Pairing

Pairing은 $e(P, Q)$처럼 두 개의 타원곡선 위의 점 $P, Q$를 입력받아 다른 그룹의 원소를 출력하는 함수이다.

$$
e:\mathbb{G}_1×\mathbb{G}_2→\mathbb{G}_T
$$

타원곡선의 generator인 $G$에서 pairing은 다음 속성을 만족한다. (bilinearity)

$$
e(a \cdot G_1, b \cdot G_2) = e(G_1, G_2)^{a \cdot b}
$$

이것을 이용하면 암호화된 상태에서도 곱셈 검증이 가능하다.

## 전달받은 증명

Verifier는 Prover에게 다음 값을 받았다.

- **Proof:** $[A] = G \cdot A(\tau), \ [B] = G \cdot B(\tau), \ [H] = G \cdot H(\tau)$
- **Verification Key (VK):** $[T] = G \cdot T(\tau)$ (Trusted Setup에서 생성)
- Public Input으로부터 계산된: Verifier가 알고 있는 공개 입력값으로부터 $[C] = G\cdot C(\tau)$를 계산

verifier는 다음 식을 검증하고 싶다.

$$
A(\tau) \cdot B(\tau) - C(\tau)= H(\tau)\cdot T(\tau)\\
A(\tau) \cdot B(\tau) = C(\tau) + H(\tau)\cdot T(\tau)
$$

하지만, 일반적으로는 $\tau$를 모르기 때문에 계산할 수 없다. 여기서 pairing을 사용한다.

$$
e(G, G)^{A(\tau)\cdot B(\tau)} = e(G, G)^{C(\tau) + H(\tau)\cdot T(\tau)}\\
e(G, G)^{A(\tau)\cdot B(\tau)} = e(G, G)^{C(\tau)}\cdot e(G, G)^{H(\tau)\cdot T(\tau)}
$$

pairing인 $e(G \cdot a, G \cdot b) = e(G, G)^{a \cdot b}$를 이용해서,

$$
e([A], [B]) = e(G\cdot A(\tau), G\cdot B(\tau))\\
= e(G, G)^{A(\tau)B(\tau)}
$$

$$
e([C], G)\cdot e([H], [T]) \\
= e(C(\tau)\cdot G, G) \cdot e(G\cdot H(\tau), G\cdot T(\tau))\\
= e(G, G)^{C(\tau)}\cdot e(G, G)^{H(\tau)\cdot T(\tau)}
$$

따라서, verifier는 단순히 다음 식만 확인하면 검증 가능하다.

$$
e([A], [B]) = e([C], G)\cdot e([H], [T])
$$

> 타원곡선의 Pairing 파트는 따로 정리해 작성하겠다.
> 

이 계산은 문제의 복잡도, $d$의 개수와 상관없이 항상 일정하게 빠르다. Pairing을 통해서 ZK-SNARK의 검증을 손쉽게 할 수 있다.

## 끝으로

지금까지 Groth16에서 QAP를 이용한 증명 생성과 검증 과정을 살펴보았다. 핵심을 정리하면:

1. **Trusted Setup**: 여러 참여자가 협력해 안전한 공개 파라미터(CRS)를 생성
2. **증명 생성**: Prover는 CRS를 이용해 witness를 암호화하여 증명을 생성
3. **증명 검증**: Verifier는 pairing을 이용해 빠르고 간결하게 검증