#include <iostream>
using namespace std;

int main() {

    int zahlen[] = {4, 7, 12, 5, 18, 21, 9, 10};
    int groesse = sizeof(zahlen) / sizeof(zahlen[0]);

    int gerade = 0;
    int ungerade = 0;
    int groesser10 = 0;
    int summe = 0;

    cout << "Zahlenanalyse startet...\n\n";

    for (int i = 0; i < groesse; i++) {

        int z = zahlen[i];
        summe += z;

        if (z % 2 == 0) {
            gerade++;
            cout << z << " ist gerade\n";
        } else {
            ungerade++;
            cout << z << " ist ungerade\n";
        }

        if (z > 10) {
            groesser10++;
            cout << "  -> " << z << " ist größer als 10\n";
        }
    }

    cout << "\n--- Ergebnis ---\n";
    cout << "Summe: " << summe << endl;
    cout << "Gerade Zahlen: " << gerade << endl;
    cout << "Ungerade Zahlen: " << ungerade << endl;
    cout << "Zahlen > 10: " << groesser10 << endl;

    return 0;
}
