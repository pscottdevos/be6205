#define CLOCK_INTERRUPT 2 // Pin 21 on the Mega

void setup() {
    Serial.begin(2000000);
    DDRA = 0b00000000;
    DDRC = 0b00000000;
    DDRL = 0b00000000;
    pinMode(CLOCK_INTERRUPT, INPUT);
    
    attachInterrupt(CLOCK_INTERRUPT, onClock, RISING);
}

void loop() {
}

void onClock() {
    unsigned int addr_low = PINA & 0b11111111;
    unsigned int addr_high = PINC & 0b11111111;
    unsigned int data = PINL & 0b11111111;
    char output[30];

    char bin[9] = "00000000";
    byte2binary(data, bin);
    sprintf(output, "%02x%02x    %s", addr_high, addr_low, bin);
    Serial.println(output);
}

void byte2binary(int b, char bin[]) {
  for (int i = 0; i < 8; ++i) {
    bin[7-i] = b & 1 ? '1' : '0';
    b >>= 1;
  }
  bin[8] = '\0';
  return bin;
}
