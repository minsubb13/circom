# circuit

## Description
I'll examine how it works through code examples. Reading this alongside the blog post should help you understand Groth16

### Writing circuit

Write a circuit. In this docs, I will explain as example `qap_example.circom`.

### Compiling circuit

```shell
circom example.circom --r1cs --wasm --sym --c
```

### Write input.json

`input.json` as a example of `qap_example` is below:

```json
{
  "x": "3",
  "out": "35"
}
```

- `x` is a privite input
- `out` is a public input

### Computing the witness

Enter in the directory `qap_example.js`, add the input in a file `input.json` and execute:

```shell
node example_js/generate_witness.js example_js/example.wasm input.json witness.wtns
```

### Powers of Tau
First, we start a new "powers of tau" ceremony

```shell
snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
```

Then, we contribute to the ceremony

```
snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
```

### Phase 2

```shell
snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v
```

Next, we generate `.zkey` file that will contain the proving and verification keys together with all phase 2 contributions. Execute the following command to start a new zkey

```
snarkjs groth16 setup example.r1cs pot12_final.ptau example_0000.zkey
```

Contribute to phase 2 of the ceremony:
```shell
snarkjs zkey contribute example_0000.zkey example_0001.zkey --name="Alice" -v
```

Export the verification key
```shell
snarkjs zkey export verificationkey example_0001.zkey verification_key.json
```

### Generating a Proof
```shell
snarkjs groth16 prove example_0001.zkey witness.wtns proof.json public.json
```

- `proof.json`: it contains the proof
- `public.json`: it contains the values of the public inputs and outputs

### Verifying a Proof
```shell
snarkjs groth16 verify verification_key.json public.json proof.json
```
