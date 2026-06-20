zahlen = [3, 7, 12, 5, 18, 21, 4, 9]

gerade = 0
ungerade = 0
groesser_10 = 0

for z in zahlen:

    if z % 2 == 0:
        gerade += 1
        print(f"{z} ist gerade")
    else:
        ungerade += 1
        print(f"{z} ist ungerade")

    if z > 10:
        groesser_10 += 1
        print(f"  -> {z} ist größer als 10")

print("\n--- Ergebnis ---")
print("Gerade Zahlen:", gerade)
print("Ungerade Zahlen:", ungerade)
print("Zahlen > 10:", groesser_10)
