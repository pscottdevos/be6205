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
    sprintf(output, "%02x %02x    %02x", addr_high, addr_low, data);
    Serial.println(output);
}
