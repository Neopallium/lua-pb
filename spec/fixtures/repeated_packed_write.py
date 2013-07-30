import repeated_packed_pb2
thing = repeated_packed_pb2.Thing()

thing.parts.append(77)
thing.parts.append(999)

f = open('repeated_packed.bin', 'wb')
f.write(thing.SerializeToString())
f.close()
