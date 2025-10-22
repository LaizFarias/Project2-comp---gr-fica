#define PI 3.14159265359

// ------------------- CONFIG -------------------
const int AUDIO_BINS = 64;
const int STAR_TOTAL = 150;
const int BAR_TOTAL  = 48;

const float BASE_R   = 0.42;   // raio principal
const float HOLE_R   = 0.12;   // raio do buraco central
const float RING_W   = 0.02;   // espessura do anel

// ------------------- FFT FUNÇÕES -------------------
float readFFTIndex(int idx){
    return texture(iChannel0, vec2(float(idx)/float(AUDIO_BINS), 0.0)).x;
}
float readFFT(float fx){
    return texture(iChannel0, vec2(fract(fx), 0.0)).x;
}
float avgSpectrum(){
    float sum = 0.0;
    for(int j=0;j<AUDIO_BINS;j++){
        sum += readFFTIndex(j);
    }
    return sum / float(AUDIO_BINS);
}

// ------------------- CORES -------------------
vec3 rainbowPulse(float tm){
    vec3 rgb;
    rgb.r = 0.5 + 0.5*sin(tm*0.2);
    rgb.g = 0.5 + 0.5*sin(tm*0.2 + 2.1);
    rgb.b = 0.5 + 0.5*sin(tm*0.2 + 4.2);
    return rgb;
}

float randomNoise(vec2 seed){
    return fract(sin(dot(seed, vec2(14.23, 83.13))) * 45217.3754);
}

// ------------------- FUNDO DE ESTRELAS -------------------
vec3 cosmicField(vec2 pos, float t, float energy, float rCirc){
    vec3 sky = vec3(0.0);
    int s = 0;
    while(s < STAR_TOTAL){
        vec2 base = vec2(float(s), float(s*s));
        vec2 p = vec2(randomNoise(base), randomNoise(base+1.1)) * 2.0 - 1.0;
        float spd = 0.22 + 0.16*randomNoise(base+2.3);
        float dst = length(p);
        float motion = mod(t*spd + dst, 2.0);
        vec2 posShift = p * (1.0 - motion);
        if(length(posShift) < rCirc){ posShift = normalize(p); }

        float d = length(pos - posShift);
        float bright = smoothstep(0.03, 0.0, d);
        vec3 cStar = rainbowPulse(t) * (0.16 + 0.45*energy);
        sky += cStar * bright;
        s++;
    }
    return clamp(sky, 0.0, 1.0);
}

// ------------------- DISTORÇÃO -------------------
vec2 warpSpace(vec2 p, float lim, float power){
    float rr = length(p);
    if(rr < lim){
        float f = 1.0 - smoothstep(0.0, lim, rr);
        p *= 1.0 - power * f * f;
    }
    return p;
}

// ------------------- ANEL MODULADO -------------------
float reactiveRing(vec2 p, float radius, float thick, float tm, float vol){
    float r = length(p);
    float ang = atan(p.y, p.x);
    if(ang < 0.0) ang += 2.0*PI;
    float normA = ang/(2.0*PI);

    float wave = sin(ang*14.5 + tm*3.2) * (0.02 + 0.07*vol);
    float c  = readFFT(normA);
    float l  = readFFT(normA - 1.0/float(AUDIO_BINS));
    float r2 = readFFT(normA + 1.0/float(AUDIO_BINS));
    float freq = (c + 0.5*l + 0.5*r2)/2.0;
    float fAmp = pow(freq, 1.7);

    float rFinal = radius + wave + fAmp*0.20;
    float w = thick * (0.6 + 1.3*fAmp);
    float diff = abs(r - rFinal);
    return smoothstep(w, w*0.25, diff);
}

// ------------------- MAIN -------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = (fragCoord.xy - 0.5*iResolution.xy)/iResolution.y;
    float t = iTime;
    float loud = avgSpectrum();

    // Círculo base aumentado
    float mainR = BASE_R + 0.10*loud;
    float coreR = HOLE_R + 0.06*loud;

    // distorção gravitacional
    vec2 fieldPos = warpSpace(uv, coreR*2.5, 0.45 + 0.35*loud);

    // fundo
    vec3 base = cosmicField(fieldPos, t, loud, mainR);

    // anel reativo
    float ringVal = reactiveRing(uv, mainR, RING_W, t, loud);
    vec3 ringClr = rainbowPulse(t) * (0.75 + 0.85*loud);
    base += ringClr * ringVal * 1.5;

    // barras radiais
    float d = length(uv);
    float ang = atan(uv.y, uv.x);
    if(ang < 0.0) ang += 2.0*PI;

    int i = 0;
    while(i < BAR_TOTAL){
        float step = float(i)/float(BAR_TOTAL);
        float angStep = step*2.0*PI;
        float freq = readFFT(step);
        float width = (2.0*PI/float(BAR_TOTAL))*0.45;
        float height = 0.08 + 0.40*pow(freq,1.5);

        float startR = mainR*0.94;
        float endR   = mainR + height;
        float dAng = abs(ang - angStep);
        dAng = min(dAng, 2.0*PI - dAng);

        float aMask = smoothstep(width, 0.0, dAng);
        float rMask = smoothstep(endR, startR, d);
        float bar = aMask*rMask;

        base += bar * ringClr * (0.65 + 0.75*freq);
        i++;
    }

    // buraco negro e disco
    float hole = 1.0 - smoothstep(coreR*0.7, coreR*1.2, length(uv));
    vec3 halo = rainbowPulse(t*0.5) * 0.35 * (0.55 + 0.55*loud);
    vec3 disk = smoothstep(coreR*0.8, coreR*1.45, length(uv)) *
                rainbowPulse(t+2.0) * (0.35 + 0.55*loud);

    base = mix(base, vec3(0.0), hole);
    base += disk*0.65;

    base = pow(base, vec3(0.9));
    fragColor = vec4(base,1.0);
}
