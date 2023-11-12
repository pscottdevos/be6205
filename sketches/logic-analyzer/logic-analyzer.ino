#define CLOCK_INTERRUPT 2 // Pin 21 on the Mega

void setup() {
    Serial.begin(2000000);
    DDRA = 0b00000000;
    DDRB = 0b00000000;
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
    unsigned int rw_data = PINB & 0b00000001;
    unsigned int data = PINL & 0b11111111;
    char output[30];

    char dbin[9] = "00000000";
    char lbin[9] = "00000000";
    char hbin[9] = "00000000";

    byte2binary(data, dbin);
    byte2binary(addr_low, lbin);
    byte2binary(addr_high, hbin);
    char rw = rw_data ? 'r' : 'W';
    sprintf(
      output, "%s%s %02x%02x   %c  %s %02x",
      hbin, lbin, addr_high, addr_low, rw, dbin, data
    );
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
