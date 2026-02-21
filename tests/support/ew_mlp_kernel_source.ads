with Ada.Characters.Latin_1;

package EW_MLP_Kernel_Source is
   --  Host-side interface notes:
   --  * Kernel name: ew_mlp_infer
   --  * Arg 0: __global const uchar* x      (batch * 64 bytes)
   --  * Arg 1: __global int* logits         (batch * 4 int32 values)
   --  * Arg 2: __global uchar* cls          (batch bytes, argmax 0..3)
   --  * NDRange: global size >= batch, 1D

   Kernel_Name : constant String := "ew_mlp_infer";
   Build_Options : constant String := "-cl-std=CL1.2";

   Input_Features : constant Positive := 64;
   Hidden_Neurons : constant Positive := 96;
   Output_Classes : constant Positive := 4;

   Arg_X : constant Natural := 0;
   Arg_Logits : constant Natural := 1;
   Arg_Cls : constant Natural := 2;

   Source : constant String :=
     "/* EW MLP quantized deterministic kernel (OpenCL C 1.2) */"
     & Ada.Characters.Latin_1.LF
     & "#define EW_MLP_INPUT 64"
     & Ada.Characters.Latin_1.LF
     & "#define EW_MLP_HIDDEN 96"
     & Ada.Characters.Latin_1.LF
     & "#define EW_MLP_OUT 4"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline uint ew_hash2(const uint a, const uint b)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  uint h = a * 1103515245u + b * 12345u + 0x9E3779B9u;"
     & Ada.Characters.Latin_1.LF
     & "  h ^= (h >> 16);"
     & Ada.Characters.Latin_1.LF
     & "  h *= 2246822519u;"
     & Ada.Characters.Latin_1.LF
     & "  h ^= (h >> 13);"
     & Ada.Characters.Latin_1.LF
     & "  h *= 3266489917u;"
     & Ada.Characters.Latin_1.LF
     & "  h ^= (h >> 16);"
     & Ada.Characters.Latin_1.LF
     & "  return h;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline int ew_jitter(const uint neuron, const uint feature)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  return (int)(ew_hash2(neuron, feature) % 3u) - 1;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline int ew_w1(const uint neuron, const uint feature)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  const uint neuron_group = neuron / 24u;"
     & Ada.Characters.Latin_1.LF
     & "  const uint feature_band = feature / 16u;"
     & Ada.Characters.Latin_1.LF
     & "  const int base = (feature_band == neuron_group) ? 3 : -1;"
     & Ada.Characters.Latin_1.LF
     & "  return base + ew_jitter(neuron, feature);"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline int ew_b1(const uint neuron)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  (void)neuron;"
     & Ada.Characters.Latin_1.LF
     & "  return -1000;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline int ew_w2(const uint out_idx, const uint neuron)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  return ((neuron / 24u) == out_idx) ? 1 : 0;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "inline int ew_b2(const uint out_idx)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  (void)out_idx;"
     & Ada.Characters.Latin_1.LF
     & "  return 0;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "__kernel void ew_mlp_infer("
     & Ada.Characters.Latin_1.LF
     & "  __global const uchar* x,"
     & Ada.Characters.Latin_1.LF
     & "  __global int* logits,"
     & Ada.Characters.Latin_1.LF
     & "  __global uchar* cls)"
     & Ada.Characters.Latin_1.LF
     & "{"
     & Ada.Characters.Latin_1.LF
     & "  const uint gid = get_global_id(0);"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "  const __global uchar* sample = x + (gid * EW_MLP_INPUT);"
     & Ada.Characters.Latin_1.LF
     & "  int hidden[EW_MLP_HIDDEN];"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "  for (uint n = 0; n < EW_MLP_HIDDEN; ++n) {"
     & Ada.Characters.Latin_1.LF
     & "    int acc = ew_b1(n);"
     & Ada.Characters.Latin_1.LF
     & "    for (uint f = 0; f < EW_MLP_INPUT; ++f) {"
     & Ada.Characters.Latin_1.LF
     & "      acc += ew_w1(n, f) * (int)sample[f];"
     & Ada.Characters.Latin_1.LF
     & "    }"
     & Ada.Characters.Latin_1.LF
     & "    hidden[n] = (acc > 0) ? acc : 0;"
     & Ada.Characters.Latin_1.LF
     & "  }"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "  const uint out_offset = gid * EW_MLP_OUT;"
     & Ada.Characters.Latin_1.LF
     & "  int best_logit = 0;"
     & Ada.Characters.Latin_1.LF
     & "  uint best_idx = 0;"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "  for (uint o = 0; o < EW_MLP_OUT; ++o) {"
     & Ada.Characters.Latin_1.LF
     & "    int acc = ew_b2(o);"
     & Ada.Characters.Latin_1.LF
     & "    for (uint n = 0; n < EW_MLP_HIDDEN; ++n) {"
     & Ada.Characters.Latin_1.LF
     & "      acc += ew_w2(o, n) * hidden[n];"
     & Ada.Characters.Latin_1.LF
     & "    }"
     & Ada.Characters.Latin_1.LF
     & "    logits[out_offset + o] = acc;"
     & Ada.Characters.Latin_1.LF
     & "    if ((o == 0u) || (acc > best_logit)) {"
     & Ada.Characters.Latin_1.LF
     & "      best_logit = acc;"
     & Ada.Characters.Latin_1.LF
     & "      best_idx = o;"
     & Ada.Characters.Latin_1.LF
     & "    }"
     & Ada.Characters.Latin_1.LF
     & "  }"
     & Ada.Characters.Latin_1.LF
     & Ada.Characters.Latin_1.LF
     & "  cls[gid] = (uchar)best_idx;"
     & Ada.Characters.Latin_1.LF
     & "}"
     & Ada.Characters.Latin_1.LF;
end EW_MLP_Kernel_Source;
