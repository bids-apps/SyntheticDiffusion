import sys

# print ('Number of arguments:', len(sys.argv), 'arguments.')
# print ('Argument List:', str(sys.argv))


from CycleGAN import *
myCycleGAN = CycleGAN()



G_X2Y_dir = sys.argv[1]
test_X_dir = sys.argv[2]
synthetic_Y_dir = sys.argv[3]
normalization_factor_X = float(sys.argv[4])
normalization_factor_Y = 1
myCycleGAN.synthesize(G_X2Y_dir, test_X_dir, normalization_factor_X, synthetic_Y_dir, normalization_factor_Y, use_resize_convolution=True)
