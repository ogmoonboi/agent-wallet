interface QuoteParams {
  inputMint: string;
  outputMint: string;
  amount: string;
  slippageBps: string;
}

export async function getJupiterQuote({
  inputMint,
  outputMint,
  amount,
  slippageBps
}: QuoteParams): Promise<any> {
  const response = await fetch(
    `https://quote-api.jup.ag/v6/quote?inputMint=${inputMint}\
&outputMint=${outputMint}\
&amount=${amount}\
&slippageBps=${slippageBps}`
  );
  const quoteResponse = await response.json();

  if (quoteResponse.error) {
    throw new Error(`Failed to get quote: ${quoteResponse.error}`);
  }

  return quoteResponse;
}