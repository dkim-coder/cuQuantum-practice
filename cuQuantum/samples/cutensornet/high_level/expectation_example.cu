/* Copyright (c) 2023, NVIDIA CORPORATION & AFFILIATES.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

// Sphinx: Expectation #1

#include <cstdlib>
#include <cstdio>
#include <cassert>
#include <complex>
#include <vector>
#include <bitset>
#include <iostream>

#include <cuda_runtime.h>
#include <cutensornet.h>


#define HANDLE_CUDA_ERROR(x) \
{ const auto err = x; \
  if( err != cudaSuccess ) \
  { printf("CUDA error %s in line %d\n", cudaGetErrorString(err), __LINE__); fflush(stdout); std::abort(); } \
};

#define HANDLE_CUTN_ERROR(x) \
{ const auto err = x; \
  if( err != CUTENSORNET_STATUS_SUCCESS ) \
  { printf("cuTensorNet error %s in line %d\n", cutensornetGetErrorString(err), __LINE__); fflush(stdout); std::abort(); } \
};


int main(int argc, char **argv)
{
  static_assert(sizeof(size_t) == sizeof(int64_t), "Please build this sample on a 64-bit architecture!");

  constexpr std::size_t fp64size = sizeof(double);

  // Sphinx: Expectation #2

  // Quantum state configuration
  constexpr int32_t numQubits = 16; // number of qubits
  const std::vector<int64_t> qubitDims(numQubits,2); // qubit dimensions
  std::cout << "Quantum circuit: " << numQubits << " qubits\n";

  // Sphinx: Expectation #3

  // Initialize the cuTensorNet library
  HANDLE_CUDA_ERROR(cudaSetDevice(0));
  cutensornetHandle_t cutnHandle;
  HANDLE_CUTN_ERROR(cutensornetCreate(&cutnHandle));
  std::cout << "Initialized cuTensorNet library on GPU 0\n";

  // Sphinx: Expectation #4

  // Define necessary quantum gate tensors in Host memory
  const double invsq2 = 1.0 / std::sqrt(2.0);
  //  Hadamard gate
  const std::vector<std::complex<double>> h_gateH {{invsq2, 0.0},  {invsq2, 0.0},
                                                   {invsq2, 0.0}, {-invsq2, 0.0}};
  //  Pauli X gate
  const std::vector<std::complex<double>> h_gateX {{0.0, 0.0}, {1.0, 0.0},
                                                   {1.0, 0.0}, {0.0, 0.0}};
  //  Pauli Y gate
  const std::vector<std::complex<double>> h_gateY {{0.0, 0.0}, {0.0, -1.0},
                                                   {0.0, 1.0}, {0.0, 0.0}};
  //  Pauli Z gate
  const std::vector<std::complex<double>> h_gateZ {{1.0, 0.0}, {0.0, 0.0},
                                                   {0.0, 0.0}, {-1.0, 0.0}};
  //  CX gate
  const std::vector<std::complex<double>> h_gateCX {{1.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0},
                                                    {0.0, 0.0}, {1.0, 0.0}, {0.0, 0.0}, {0.0, 0.0},
                                                    {0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}, {1.0, 0.0},
                                                    {0.0, 0.0}, {0.0, 0.0}, {1.0, 0.0}, {0.0, 0.0}};

  // Copy quantum gates to Device memory
  void *d_gateH{nullptr}, *d_gateX{nullptr}, *d_gateY{nullptr}, *d_gateZ{nullptr}, *d_gateCX{nullptr};
  HANDLE_CUDA_ERROR(cudaMalloc(&d_gateH, 4 * (2 * fp64size)));
  HANDLE_CUDA_ERROR(cudaMalloc(&d_gateX, 4 * (2 * fp64size)));
  HANDLE_CUDA_ERROR(cudaMalloc(&d_gateY, 4 * (2 * fp64size)));
  HANDLE_CUDA_ERROR(cudaMalloc(&d_gateZ, 4 * (2 * fp64size)));
  HANDLE_CUDA_ERROR(cudaMalloc(&d_gateCX, 16 * (2 * fp64size)));
  std::cout << "Allocated quantum gate memory on GPU\n";
  HANDLE_CUDA_ERROR(cudaMemcpy(d_gateH, h_gateH.data(), 4 * (2 * fp64size), cudaMemcpyHostToDevice));
  HANDLE_CUDA_ERROR(cudaMemcpy(d_gateX, h_gateX.data(), 4 * (2 * fp64size), cudaMemcpyHostToDevice));
  HANDLE_CUDA_ERROR(cudaMemcpy(d_gateY, h_gateY.data(), 4 * (2 * fp64size), cudaMemcpyHostToDevice));
  HANDLE_CUDA_ERROR(cudaMemcpy(d_gateZ, h_gateZ.data(), 4 * (2 * fp64size), cudaMemcpyHostToDevice));
  HANDLE_CUDA_ERROR(cudaMemcpy(d_gateCX, h_gateCX.data(), 16 * (2 * fp64size), cudaMemcpyHostToDevice));
  std::cout << "Copied quantum gates to GPU memory\n";

  // Sphinx: Expectation #5

  // Query the free memory on Device
  std::size_t freeSize{0}, totalSize{0};
  HANDLE_CUDA_ERROR(cudaMemGetInfo(&freeSize, &totalSize));
  const std::size_t scratchSize = (freeSize - (freeSize % 4096)) / 2; // use half of available memory with alignment
  void *d_scratch{nullptr};
  HANDLE_CUDA_ERROR(cudaMalloc(&d_scratch, scratchSize));
  std::cout << "Allocated " << scratchSize << " bytes of scratch memory on GPU\n";

  // Sphinx: Expectation #6

  // Create the initial quantum state
  cutensornetState_t quantumState;
  HANDLE_CUTN_ERROR(cutensornetCreateState(cutnHandle, CUTENSORNET_STATE_PURITY_PURE, numQubits, qubitDims.data(),
                    CUDA_C_64F, &quantumState));
  std::cout << "Created the initial quantum state\n";

  // Sphinx: Expectation #7

  // Construct the final quantum circuit state (apply quantum gates) for the GHZ circuit
  int64_t id;
  HANDLE_CUTN_ERROR(cutensornetStateApplyTensor(cutnHandle, quantumState, 1, std::vector<int32_t>{{0}}.data(),
                    d_gateH, nullptr, 1, 0, 1, &id));
  for(int32_t i = 1; i < numQubits; ++i) {
    HANDLE_CUTN_ERROR(cutensornetStateApplyTensor(cutnHandle, quantumState, 2, std::vector<int32_t>{{i-1,i}}.data(),
                      d_gateCX, nullptr, 1, 0, 1, &id));
  }
  std::cout << "Applied quantum gates\n";

  // Sphinx: Expectation #8

  // Create an empty tensor network operator
  cutensornetNetworkOperator_t hamiltonian;
  HANDLE_CUTN_ERROR(cutensornetCreateNetworkOperator(cutnHandle, numQubits, qubitDims.data(), CUDA_C_64F, &hamiltonian));
  // Append component (0.5 * Z1 * Z2) to the tensor network operator
  {
    const int32_t numModes[] = {1, 1}; // Z1 acts on 1 mode, Z2 acts on 1 mode
    const int32_t modesZ1[] = {1}; // state modes Z1 acts on
    const int32_t modesZ2[] = {2}; // state modes Z2 acts on
    const int32_t * stateModes[] = {modesZ1, modesZ2}; // state modes (Z1 * Z2) acts on
    const void * gateData[] = {d_gateZ, d_gateZ}; // GPU pointers to gate data
    HANDLE_CUTN_ERROR(cutensornetNetworkOperatorAppendProduct(cutnHandle, hamiltonian, cuDoubleComplex{0.5,0.0},
                      2, numModes, stateModes, NULL, gateData, &id));
  }
  // Append component (0.25 * Y3) to the tensor network operator
  {
    const int32_t numModes[] = {1}; // Y3 acts on 1 mode
    const int32_t modesY3[] = {3}; // state modes Y3 acts on
    const int32_t * stateModes[] = {modesY3}; // state modes (Y3) acts on
    const void * gateData[] = {d_gateY}; // GPU pointers to gate data
    HANDLE_CUTN_ERROR(cutensornetNetworkOperatorAppendProduct(cutnHandle, hamiltonian, cuDoubleComplex{0.25,0.0},
                      1, numModes, stateModes, NULL, gateData, &id));
  }
  // Append component (0.13 * Y0 X2 Z3) to the tensor network operator
  {
    const int32_t numModes[] = {1, 1, 1}; // Y0 acts on 1 mode, X2 acts on 1 mode, Z3 acts on 1 mode
    const int32_t modesY0[] = {0}; // state modes Y0 acts on
    const int32_t modesX2[] = {2}; // state modes X2 acts on
    const int32_t modesZ3[] = {3}; // state modes Z3 acts on
    const int32_t * stateModes[] = {modesY0, modesX2, modesZ3}; // state modes (Y0 * X2 * Z3) acts on
    const void * gateData[] = {d_gateY, d_gateX, d_gateZ}; // GPU pointers to gate data
    HANDLE_CUTN_ERROR(cutensornetNetworkOperatorAppendProduct(cutnHandle, hamiltonian, cuDoubleComplex{0.13,0.0},
                      3, numModes, stateModes, NULL, gateData, &id));
  }
  std::cout << "Constructed a tensor network operator: (0.5 * Z1 * Z2) + (0.25 * Y3) + (0.13 * Y0 * X2 * Z3)" << std::endl;

  // Sphinx: Expectation #9

  // Specify the quantum circuit expectation value
  cutensornetStateExpectation_t expectation;
  HANDLE_CUTN_ERROR(cutensornetCreateExpectation(cutnHandle, quantumState, hamiltonian, &expectation));
  std::cout << "Created the specified quantum circuit expectation value\n";

  // Sphinx: Expectation #10

  // Configure the computation of the specified quantum circuit expectation value
  const int32_t numHyperSamples = 8; // desired number of hyper samples used in the tensor network contraction path finder
  HANDLE_CUTN_ERROR(cutensornetExpectationConfigure(cutnHandle, expectation,
                    CUTENSORNET_EXPECTATION_OPT_NUM_HYPER_SAMPLES, &numHyperSamples, sizeof(numHyperSamples)));

  // Sphinx: Expectation #11

  // Prepare the specified quantum circuit expectation value for computation
  cutensornetWorkspaceDescriptor_t workDesc;
  HANDLE_CUTN_ERROR(cutensornetCreateWorkspaceDescriptor(cutnHandle, &workDesc));
  std::cout << "Created the workspace descriptor\n";
  HANDLE_CUTN_ERROR(cutensornetExpectationPrepare(cutnHandle, expectation, scratchSize, workDesc, 0x0));
  std::cout << "Prepared the specified quantum circuit expectation value\n";

  // Sphinx: Expectation #12

  // Attach the workspace buffer
  int64_t worksize {0};
  HANDLE_CUTN_ERROR(cutensornetWorkspaceGetMemorySize(cutnHandle,
                                                      workDesc,
                                                      CUTENSORNET_WORKSIZE_PREF_RECOMMENDED,
                                                      CUTENSORNET_MEMSPACE_DEVICE,
                                                      CUTENSORNET_WORKSPACE_SCRATCH,
                                                      &worksize));
  std::cout << "Required scratch GPU workspace size (bytes) = " << worksize << std::endl;
  if(worksize <= scratchSize) {
    HANDLE_CUTN_ERROR(cutensornetWorkspaceSetMemory(cutnHandle, workDesc, CUTENSORNET_MEMSPACE_DEVICE,
                      CUTENSORNET_WORKSPACE_SCRATCH, d_scratch, worksize));
  }else{
    std::cout << "ERROR: Insufficient workspace size on Device!\n";
    std::abort();
  }
  std::cout << "Set the workspace buffer\n";

  // Sphinx: Expectation #13

  // Compute the specified quantum circuit expectation value
  std::complex<double> expectVal{0.0,0.0}, stateNorm{0.0,0.0};
  HANDLE_CUTN_ERROR(cutensornetExpectationCompute(cutnHandle, expectation, workDesc,
                    static_cast<void*>(&expectVal), static_cast<void*>(&stateNorm), 0x0));
  std::cout << "Computed the specified quantum circuit expectation value\n";
  std::cout << "Expectation value = (" << expectVal.real() << ", " << expectVal.imag() << ")\n";
  std::cout << "State 2-norm = (" << stateNorm.real() << ", " << stateNorm.imag() << ")\n";

  // Sphinx: Expectation #14

  // Destroy the workspace descriptor
  HANDLE_CUTN_ERROR(cutensornetDestroyWorkspaceDescriptor(workDesc));
  std::cout << "Destroyed the workspace descriptor\n";

  // Destroy the quantum circuit expectation value
  HANDLE_CUTN_ERROR(cutensornetDestroyExpectation(expectation));
  std::cout << "Destroyed the quantum circuit state expectation value\n";

  // Destroy the tensor network operator
  HANDLE_CUTN_ERROR(cutensornetDestroyNetworkOperator(hamiltonian));
  std::cout << "Destroyed the tensor network operator\n";

  // Destroy the quantum circuit state
  HANDLE_CUTN_ERROR(cutensornetDestroyState(quantumState));
  std::cout << "Destroyed the quantum circuit state\n";

  HANDLE_CUDA_ERROR(cudaFree(d_scratch));
  HANDLE_CUDA_ERROR(cudaFree(d_gateCX));
  HANDLE_CUDA_ERROR(cudaFree(d_gateZ));
  HANDLE_CUDA_ERROR(cudaFree(d_gateY));
  HANDLE_CUDA_ERROR(cudaFree(d_gateX));
  HANDLE_CUDA_ERROR(cudaFree(d_gateH));
  std::cout << "Freed memory on GPU\n";

  // Finalize the cuTensorNet library
  HANDLE_CUTN_ERROR(cutensornetDestroy(cutnHandle));
  std::cout << "Finalized the cuTensorNet library\n";

  return 0;
}
