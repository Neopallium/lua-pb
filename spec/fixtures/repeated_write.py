import repeated_pb2
thing = repeated_pb2.Thing()

thing.parts.append(44)
thing.parts.append(55)

f = open('repeated.bin', 'wb')
f.write(thing.SerializeToString())
f.close()
