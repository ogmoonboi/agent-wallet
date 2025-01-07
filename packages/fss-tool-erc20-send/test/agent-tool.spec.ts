import type { SendERC20LitActionParameters } from '../src/lib/tool';
import { SendERC20 } from '../src/lib/tool';

describe('SendERC20', () => {
  const validParams: SendERC20LitActionParameters = {
    tokenIn: '0x1234567890123456789012345678901234567890',
    recipientAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
    amountIn: '1.5',
    chainId: '1',
    rpcUrl: 'https://eth-mainnet.example.com',
  };

  describe('SendERC20.parameters.schema', () => {
    it('should validate correct parameters', () => {
      const result = SendERC20.parameters.schema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    describe('tokenIn validation', () => {
      it('should reject invalid Ethereum addresses', () => {
        const invalidTokens = [
          '0x123', // too short
          '0xGGGG567890123456789012345678901234567890', // invalid hex
          '1234567890123456789012345678901234567890', // missing 0x prefix
          '0x12345678901234567890123456789012345678901', // too long
        ];

        invalidTokens.forEach((tokenIn) => {
          const result = SendERC20.parameters.schema.safeParse({
            ...validParams,
            tokenIn,
          });
          expect(result.success).toBe(false);
        });
      });
    });

    describe('recipientAddress validation', () => {
      it('should reject invalid Ethereum addresses', () => {
        const invalidAddresses = [
          '0x123', // too short
          '0xGGGGdefabcdefabcdefabcdefabcdefabcdefabcd', // invalid hex
          'abcdefabcdefabcdefabcdefabcdefabcdefabcd', // missing 0x prefix
          '0xabcdefabcdefabcdefabcdefabcdefabcdefabcde', // too long
        ];

        invalidAddresses.forEach((recipientAddress) => {
          const result = SendERC20.parameters.schema.safeParse({
            ...validParams,
            recipientAddress,
          });
          expect(result.success).toBe(false);
        });
      });
    });

    describe('amountIn validation', () => {
      it('should accept valid decimal numbers as strings', () => {
        const validAmounts = ['1.5', '100', '0.01', '1000.55555'];

        validAmounts.forEach((amountIn) => {
          const result = SendERC20.parameters.schema.safeParse({
            ...validParams,
            amountIn,
          });
          expect(result.success).toBe(true);
        });
      });

      it('should reject invalid amounts', () => {
        const invalidAmounts = [
          'abc', // not a number
          '1.2.3', // multiple decimals
          '-1.5', // negative numbers
          '1,5', // wrong decimal separator
          '', // empty string
        ];

        invalidAmounts.forEach((amountIn) => {
          const result = SendERC20.parameters.schema.safeParse({
            ...validParams,
            amountIn,
          });
          expect(result.success).toBe(false);
        });
      });
    });
  });

  describe('SendERC20.parameters.validate', () => {
    it('should return true for valid parameters', () => {
      expect(SendERC20.parameters.validate(validParams)).toBe(true);
    });

    it('should return array of errors for invalid parameters', () => {
      const invalidParams = [
        {
          ...validParams,
          tokenIn: '0x123', // invalid address
        },
        {
          ...validParams,
          amountIn: 'abc', // invalid amount
        },
        {
          tokenIn: validParams.tokenIn,
          // missing parameters
        },
        null,
        undefined,
        'not an object',
        [],
      ];

      invalidParams.forEach((params) => {
        const result = SendERC20.parameters.validate(params);
        expect(Array.isArray(result)).toBe(true);
        if (Array.isArray(result)) {
          expect(result.length).toBeGreaterThan(0);
          expect(result[0]).toMatchObject({
            error: expect.any(String),
          });
          // param field may be undefined for some validation errors
          if (result[0].param !== undefined) {
            expect(typeof result[0].param).toBe('string');
          }
        }
      });
    });
  });

  describe('SendERC20 metadata', () => {
    it('should have the correct structure', () => {
      expect(SendERC20).toMatchObject({
        name: expect.any(String),
        description: expect.any(String),
        parameters: expect.any(Object),
      });
    });

    it('should have descriptions for all parameters', () => {
      const params = Object.keys(SendERC20.parameters.descriptions);
      const required = ['tokenIn', 'recipientAddress', 'amountIn', 'chainId', 'rpcUrl'];
      expect(params.sort()).toEqual(required.sort());
    });
  });
});
