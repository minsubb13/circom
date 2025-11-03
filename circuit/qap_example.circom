pragma circom 2.0.0;

// f(x) = x^3 + x + 5 = 35
// sym_1 = x * x
// y = sym_1 * x
// sym_2 = y + x
// out = sym_2 + 5

template QAP_example() {
  signal input x;
  signal input out;

  signal sym_1;
  signal y;
  signal sym_2;
  signal ret;

  sym_1 <== x * x;
  y <== sym_1 * x;
  sym_2 <== y + x;
  ret <== sym_2 + 5;

  ret === out;
}

component main = QAP_example();
