import torch
import torch.nn as nn
from src.models.attention import MultiHeadAttention
from src.models.mlp import MLP

class Block(nn.Module):
    """
    A single Transformer block.

    This block consists of a multi-head attention layer followed by an MLP,
    with layer normalization and residual connections.

    Args:
        n_head (int): The number of attention heads in the multi-head attention layer.
        n_embed (int): The dimensionality of the input embedding.
        context_length (int): The maximum length of the input sequence.
    """
    def __init__(self, n_head: int, n_embed: int, context_length: int) -> None:
        """
        Initializes the Transformer block.

        Args:
            n_head (int): The number of attention heads.
            n_embed (int): The dimensionality of the embedding space.
            context_length (int): The maximum sequence length.
        """
        super().__init__()
        self.ln1 = nn.LayerNorm(n_embed)
        self.attn = MultiHeadAttention(n_head, n_embed, context_length)
        self.ln2 = nn.LayerNorm(n_embed)
        self.mlp = MLP(n_embed)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass through the Transformer block.

        Args:
            x (torch.Tensor): Input tensor.

        Returns:
            torch.Tensor: Output tensor after the block.
        """
        # Apply multi-head attention with residual connection
        x = x + self.attn(self.ln1(x))
        # Apply MLP with residual connection
        x = x + self.mlp(self.ln2(x))
        return x

    def forward_embedding(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        """
        Forward pass focusing on the embedding and attention parts.

        Args:
            x (torch.Tensor): Input tensor.

        Returns:
            tuple: A tuple containing the output after MLP embedding and the residual.
        """
        res = x + self.attn(self.ln1(x))
        x = self.mlp.forward_embedding(self.ln2(res))
        return x, res

if __name__ == '__main__':
    # Example Usage (optional, for testing the module independently)
    batch_size = 2
    sequence_length = 5
    embedding_dim = 32
    num_heads = 4
    context_len = 5
    input_tensor = torch.randn(batch_size, sequence_length, embedding_dim)

    transformer_block = Block(n_head=num_heads, n_embed=embedding_dim, context_length=context_len)
    output_tensor = transformer_block(input_tensor)

    print("Transformer Block Input Shape:", input_tensor.shape)
    print("Transformer Block Output Shape:", output_tensor.shape)