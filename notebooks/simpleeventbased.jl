### A Pluto.jl notebook ###
# v0.19.19

using Markdown
using InteractiveUtils

# ╔═╡ bac63278-6578-42bc-b4a0-4e88cf860dce
import Pkg

# ╔═╡ a91bcfcd-06ae-4ae9-a87a-add45f09a3c0
Pkg.activate(".")

# ╔═╡ a7ac7f42-929f-11ed-2b7c-d73fc7759c3a
using Revise

# ╔═╡ 839bc204-f9cf-4d6f-be1c-291fdd038f22
html"""
<style>
	main {
		margin: 0 auto;
		max-width: 2000px;
    	padding-left: max(160px, 10%);
    	padding-right: max(160px, 10%);
	}
</style>
"""

# ╔═╡ 7448a4ee-c29a-42c8-ab7e-9b1086ac1b55
md"# Doing event based simulation with `MINDFul.jl`"

# ╔═╡ Cell order:
# ╠═839bc204-f9cf-4d6f-be1c-291fdd038f22
# ╟─7448a4ee-c29a-42c8-ab7e-9b1086ac1b55
# ╠═a7ac7f42-929f-11ed-2b7c-d73fc7759c3a
# ╠═bac63278-6578-42bc-b4a0-4e88cf860dce
# ╠═a91bcfcd-06ae-4ae9-a87a-add45f09a3c0
