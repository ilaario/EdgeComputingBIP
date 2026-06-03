
#define VEC_LEN 15
int vec_a [VEC_LEN];

int main() {
    // Init the vector
    for (int i = 0; i < VEC_LEN; i++) vec_a[i] = i;

    // Sum for first vec_len squares
    int acc = 0;
    
    for (int i = 0; i < VEC_LEN; i++) {
        int a = vec_a[i];
        acc += a * a;
    }

    // Return code should be 1015 for 15 VEC_LEN
    return acc;
}
