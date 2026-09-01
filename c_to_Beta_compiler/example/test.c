{
    int x;
    int y;
    int i;
    int suma;

    x = 5;
    y = 10;
    suma = 0;

    if(x < 8){
        y = y + 1;
    }else{
        y = 0;
    }

    while(y > 0){
        suma = suma + y;
        y = y - 1;
    }

    for(i = 1; i <= 5; i = i + 1){
        suma = suma + i;
    }

    return suma;
}
