# Generates the difference exercises

import numpy as np
from matplotlib.pyplot import *


## Basic: Sorting algorithm
array =  map(lambda x: int(x), np.random.uniform(0,1000,100))
output = reduce(lambda x,y: str(x)+","+str(y),array)
    
FILE = open("beginner.txt",'w')
FILE.write(output)
FILE.close()

## Intermediate: Pulse signal to noise

def gaussian(x,a,b,c):
    return a*np.exp(-0.5*((x-float(b))/float(c))**2)

N = 200
t = np.arange(0,N)
y = gaussian(t,1.5,50,7)
array = np.zeros((10,200))
output = ""
for i in range(10):
    noise = np.random.normal(0,0.15,N)
    array[i] = y + noise
    output += reduce(lambda x,y: str(x)+","+str(y), array[i]) + "\n"
#    plot(t,array[i]+i,'k.')
#plot(t,np.mean(array,axis=0),'bo')
#show()

FILE = open("intermediate.txt",'w')
FILE.write(output)
FILE.close()

## Advanced: Low S/N pulse series to smooth, fold.


N = 200
t = np.arange(0,N)
y = gaussian(t,0.025,50,7)
array = np.zeros((200,200))
output = ""
for i in range(200):
    noise = np.random.normal(0,0.15,N)
    array[i] = y + noise
    output += reduce(lambda x,y: str(x)+","+str(y), array[i])

#    plot(t,array[i]+i,'k.')
z = np.mean(array,axis=0)
newz = np.zeros(20)
for i in range(20):
    newz[i] = np.mean(z[10*i:10*(i+1)])
#plot(np.arange(0,N,10),newz,'ro')
#plot(t,z,'k.')
#show()


FILE = open("advanced.txt",'w')
FILE.write(output)
FILE.close()
