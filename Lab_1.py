
#____________________________
# Name: Prahlad Menon
# Email: pkm5568@psu.edu
# Class: CMPSC 131 Section 001
# Lab #1
#____________________________

import random

print("Questionare")

First_name = input("First Name: ")
Last_name = input("Last Name: ")
Birth_year = input("Birth year: ")

Birth_year_actual = int(Birth_year)

age = 2025-Birth_year_actual

animals = ['Tiger', 'Lion', 'Giraffe', 'Zebra', 'Elephant'] 

print("Thank you very much", First_name, Last_name)

print("Your temporary password is", Last_name, "*", age, "*", random.choice(animals))