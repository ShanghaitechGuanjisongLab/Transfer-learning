## Highlights

•

UTX and JMJD3 maintain ILC3 subset balance via H3K27me3 erasure at key loci

•

TCF-1 is a central effector downstream of UTX for IL-22/IL-17A regulation

•

Single-cell RNA-seq reveals UTX/JMJD3 ablation rewires ILC3 lineage trajectories

•

H3K4me3 and H3K27me3 antagonistically regulate ILC3 specification and effector functions

## Summary

Group 3 innate lymphoid cells (ILC3s) exhibit dynamic plasticity, with their differentiation and function orchestrated by epigenetic mechanisms, including histone modifications and DNA methylation. We identify the histone demethylases UTX and JMJD3 as pivotal regulators of ILC3 specialization. Their deficiency disrupts subset balance: NKp46<sup>+</sup> ILC3s are depleted with impaired IL-22 production, whereas CCR6<sup>+</sup> ILC3s expand and exhibit enhanced IL-17A-mediated antifungal immunity. Single-cell profiling reveals that UTX/JMJD3 ablation epigenetically restricts double-negative (DN)-to-NKp46<sup>+</sup> differentiation while potentiating CCR6<sup>+</sup> polarization, rewiring ILC3 lineage trajectories through chromatin remodeling. Cleavage under targets and tagmentation (CUT&Tag) analysis demonstrates that UTX directly occupies enhancer regions upstream of _Tcf7_, where it catalyzes H3K27me3 demethylation to maintain an open chromatin state. Retroviral Tcf7 reconstitution rescues the NKp46<sup>+</sup> ILC3 deficit and normalizes cytokine production, positioning TCF7 as the key effector downstream of UTX. These findings establish UTX/JMJD3 as central epigenetic gatekeepers of mucosal immunity, offering therapeutic avenues for inflammatory disorders driven by ILC3 dysregulation.

## Graphical abstract

[![Graphical abstract undfig1](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/0ecfc5a9-faa5-408a-9a2c-a02a7bf9b38c/main.assets/fx1.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/2a6e6cc6-a981-45fe-8f4f-efa17fabaced/main.assets/fx1_lrg.jpg "View full size image in a new tab")

## Keywords

1.  [ILC3 differentiation](https://www.cell.com/action/doSearch?AllField=%22ILC3+differentiation%22&ISSN=2211-1247)
2.  [epigenetic modification](https://www.cell.com/action/doSearch?AllField=%22epigenetic+modification%22&ISSN=2211-1247)
3.  [H3K27me3](https://www.cell.com/action/doSearch?AllField=%22H3K27me3%22&ISSN=2211-1247)
4.  [UTX](https://www.cell.com/action/doSearch?AllField=%22UTX%22&ISSN=2211-1247)
5.  [JMJD3](https://www.cell.com/action/doSearch?AllField=%22JMJD3%22&ISSN=2211-1247)

## Research topic(s)

1.  [CP: immunology](https://www.cell.com/action/doSearch?AllField=%22CP%3A+immunology%22&ISSN=2211-1247)
2.  [CP: molecular biology](https://www.cell.com/action/doSearch?AllField=%22CP%3A+molecular+biology%22&ISSN=2211-1247)

## Introduction

Group 3 innate lymphoid cells (ILC3s) are crucial components of the innate immune system, predominantly located in mucosal tissues such as the intestines, lungs, and skin.[<sup>1</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) They play a pivotal role in maintaining the integrity of the mucosal barrier, defending against pathogen invasion, and regulating tissue repair and inflammatory responses.[<sup>2</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Dysfunction of ILC3s is closely associated with various diseases, including inflammatory bowel disease (IBD), infectious diseases, autoimmune disorders,[<sup>3</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) and cancer.[<sup>4</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Based on surface markers and functions, ILC3s can be further classified into several subsets: lymphoid tissue inducer cells (LTi cells), which express the chemokine receptor CCR6 and participate in the formation of lymphoid tissues during embryonic development[<sup>5</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>6</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#); NKp46<sup>+</sup> ILC3s, which express natural killer cell receptors such as NKp44/46; and another subset known as double-negative ILC3s (DN ILC3s), which neither express NKp46 nor CCR6.[<sup>7</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>8</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>9</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) ILC3s can act as innate immune cells, rapidly responding to changes in microbial and tissue microenvironments by secreting cytokines such as IL-22 and IL-17 to maintain the integrity of the intestinal mucosal barrier.[<sup>10</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>11</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Additionally, they can interact with dendritic cells, T cells, and others to regulate the initiation and intensity of adaptive immune responses.[<sup>12</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>13</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) This dual functionality positions ILC3s as key players in immune homeostasis and disease pathogenesis.

The function and phenotype of ILC3s are regulated by both transcriptional and epigenetic mechanisms. In ILC3s, CCR6<sup>−</sup>NKp46<sup>−</sup> ILC3s in the gut can reduce the expression of the transcription factor RORγt while increasing the expression of T-bet.[<sup>8</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>14</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>15</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Through CCR6<sup>−</sup>NKp46<sup>+</sup> as an intermediate state, they can transition into ex-ILC3 cells.[<sup>16</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>17</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) The expression of NKp46 in ILC3s is relatively unstable, and lineage tracing techniques (fate mapping) have revealed that the CD4<sup>−</sup> subset of CCR6<sup>+</sup> ILC3s once expressed NKp46, providing evidence for the differentiation of NKp46<sup>+</sup> ILC3s into LTi-like cells.[<sup>18</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Epigenetic modifications play a pivotal role in orchestrating the differentiation and functional specialization of ILCs, particularly ILC3s. DNA methylation and hydroxymethylation dynamically regulate ILC3 development and effector programs by shaping transcriptional landscapes.[<sup>19</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) For instance, the gut microbiota modulates TET1-mediated DNA hydroxymethylation programs to fine-tune ILC1 differentiation, highlighting the interplay between environmental signals and epigenetic rewiring.[<sup>20</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Beyond DNA modifications, histone post-translational modifications critically influence ILC3 plasticity. The histone methyltransferase G9a suppresses ILC3 transcriptional programs to promote ILC2 lineage commitment,[<sup>21</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) while Sirtuin 6 restricts IL-22 production in ILC3s through deacetylation-dependent repression of inflammatory gene enhancers,[<sup>22</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) thereby balancing intestinal immune homeostasis. Notably, SETD2-mediated H3K36me3 deposition governs the functional diversification of intestinal ILC3 subsets by stabilizing chromatin states at loci encoding barrier-protective cytokines and chemokines.[<sup>23</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) These findings underscore a multilayered epigenetic network that integrates microbial cues, metabolic signals, and transcriptional regulators to calibrate ILC3 responses in mucosal tissues.

Among epigenetic modifications, the antagonistic interplay between H3K27me3 (a repressive mark) and H3K4me3 (an activating mark) has garnered significant attention for its critical role in balancing gene activation and silencing during immune cell differentiation. In CD4<sup>+</sup> T cells, these marks exhibit remarkable plasticity, co-regulating lineage-specific transcriptional programs to dictate cell fate decisions. Studies have demonstrated that H3K4me3 enrichment at promoter and enhancer regions licenses effector gene expression, whereas H3K27me3 deposition reinforces transcriptional repression at alternative lineage loci, creating a chromatin-based “toggle” mechanism that ensures precise lineage commitment.[<sup>24</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Intriguingly, this paradigm extends to ILCs, where H3K4me3 distribution displays subset-specific heterogeneity. In CCR6<sup>+</sup> ILC3s, reduced H3K4me3 occupancy at effector loci correlates with restrained cytokine production, contrasting with the unaltered chromatin states observed in NKp46<sup>+</sup> ILC3s.[<sup>25</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Despite these advances, the mechanisms linking dynamic H3K27me3 remodeling to ILC3 functional adaptation remain poorly understood, particularly how site-specific demethylation by UTX/JMJD3 governs subset equilibrium and mucosal immune responses.

In this article, we demonstrate the critical role of the demethylases UTX and JMJD3 in the transdifferentiation of ILC3s into other ILC subsets. Through cleavage under targets and tagmentation (CUT&Tag) data analysis of H3K27me3 and H3K4me3 in intestinal lamina propria ILC3s, we found that H3K27me3 modification levels are highly correlated with ILC3 homeostasis in murine intestinal ILC3s. Phenotypic analysis of Jmjd3-single-knockout (JKO), Utx-single-KO (UKO), and Jmjd3/Utx-double-KO (DKO) mice revealed a significant decrease in NKp46<sup>+</sup> ILC3s and a marked increase in CCR6<sup>+</sup> ILC3s, suggesting potential transdifferentiation. In Utx/Jmjd3-DKO mice, intestinal NKp46<sup>+</sup> ILC3s were significantly reduced with diminished IL-22 secretion, while CCR6<sup>+</sup> ILC3s increased and enhanced IL-17A-mediated antifungal capacity. Integrative analysis reveals that the absence of UTX/JMJD3 restricts the differentiation of DN to NKp46<sup>+</sup> while promoting CCR6<sup>+</sup> polarization. UTX occupies the enhancer region upstream of Tcf7, where it catalyzes H3K27me3 demethylation. Furthermore, Tcf7 overexpression partially restores the differentiation and functional defects of NKp46<sup>+</sup>ILC3s following UTX deficiency while reverting the expansion of CCR6<sup>+</sup> ILC3s and the secretion of IL-17A to normal levels. In the context of ILC3 biology, our work extends these paradigms by demonstrating that UTX/JMJD3 ablation shifts the equilibrium between CCR6<sup>+</sup> and NKp46<sup>+</sup> subsets through H3K27me3-dependent chromatin remodeling.

## Results

### H3K27me3 and H3K4me3 exhibit subset-specific profiles across ILC3 subpopulations

The dynamic interplay between activating (H3K4me3) and repressive (H3K27me3) histone modifications constitutes a fundamental epigenetic mechanism governing immune cell differentiation and functional specialization.[<sup>1</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) In intestinal ILC3s, our integrated CUT&Tag analysis reveals distinct chromatin landscapes: H3K27me3 predominantly occupies intergenic regions (25%) and promoter regions (26%), while H3K4me3 concentrates near transcriptional start sites (TSSs; 45%) ([Figures S1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A and S1B). The predominance of H3K4me3 in CCR6<sup>+</sup> ILC3s suggests the activation of genes related to effector functions in these cells, potentially involving inflammatory responses and immune defense ([Figures 1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig1)A and 1B). Conversely, the predominance of H3K27me3 in NKp46<sup>+</sup> ILC3s indicates the repression of certain gene expressions in these cells, most likely associated with cytotoxicity and developmental regulation ([Figure 1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig1)C).

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/f4b1ecca-2a8e-475d-88e2-28f39418e950/main.assets/gr1.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/8a4986bc-e347-4e26-84a8-192b375be0b3/main.assets/gr1_lrg.jpg "View full size image in a new tab")

Figure 1 H3K27me3 exhibits stage-specific epigenetic regulation during ILC development and colitis pathogenesis

Subset-specific profiling uncovers divergent epigenetic programming—CCR6<sup>+</sup> ILC3s exhibit H3K4me3 dominance (58% of modified loci, 8,613 genes) associated with effector gene activation (_Ccr6_, _Il17a/f_, _Bcl6_, and _Zbtb46_), whereas NKp46<sup>+</sup> ILC3s display H3K27me3 predominance (69% of peaks, 4,805 genes) regulating cytotoxic potential (_Ncr1_, _Tbx21_, and _Xcl1_) ([Figures 1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig1)A–1F, [S1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)C, and S1D). Unsupervised _k_\-means clustering reveals three activation states (clusters I–III: H3K4me3+) and one repressive state (cluster IV: H3K27me3+) ([Figure 1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig1)D). Functional annotation of cluster IV demonstrates striking enrichment in IBD pathways and the key immune regulators JAK-STAT signaling and NF-κB activation, which orchestrate ILC3 maturation, cytokine production, and mucosal crosstalk through IL-23/IL-1β axis modulation[<sup>2</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) ([Figure 1](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig1)E).

The distinct distribution patterns of H3K4me3 and H3K27me3 may reflect the unique epigenetic regulatory events experienced by different subpopulations during development, ultimately determining their maturation states. Specifically, CCR6<sup>+</sup> ILC3s and NKp46<sup>+</sup> ILC3s exhibit distinct differentiation trajectories and developmental dynamics. CCR6<sup>+</sup> ILC3s (LTi cells), which persist postnatally, play indispensable roles in orchestrating secondary lymphoid tissue organogenesis.[<sup>5</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>6</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) In contrast, NKp46<sup>+</sup> ILC3s emerge postnatally, populating intestinal niches by 2 weeks of age in mice,[<sup>26</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>27</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) while CCR6<sup>−</sup>NKp46<sup>−</sup> ILC3s (DN ILC3s) retain the capacity to differentiate into terminally committed NKp46<sup>+</sup> subsets under microenvironmental cues. These differences in epigenetic signatures are likely intertwined with the differentiation and developmental pathways of ILC3s, highlighting the intricate interplay between epigenetic regulation and cellular fate determination in the context of immune cell development.

### UTX- and JMJD3-mediated H3K27me3 demethylases intrinsically maintain intestinal ILC3 homeostasis

To mechanistically dissect H3K27me3 dynamics, we generated conditional KO models: _Jmjd3_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> (JKO), _Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> (UKO), and DKO mice, enabling precise ablation of H3K27me3 demethylases in ILC3-committed cells while preserving hematopoietic precursors.[<sup>3</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) We performed a capillary western immunoassay on sorted ILC3 populations from _Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> and control (Ctrl) mice to validate the KO efficiency of UTX and JMJD3 in intestinal ILC3s. Both UTX and JMJD3 protein levels were significantly downregulated in deficient ILC3s, confirming efficient ablation ([Figures S2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S2D). We analyzed ILC progenitor development in bone marrow (BM). Flow cytometry of common lymphoid progenitors (CLPs; Lin<sup>−</sup>IL-7R<sup>+</sup>c-KitintSca-1intFlt3<sup>+</sup>), common helper-like innate lymphoid progenitors (CHILPs, Lin<sup>−</sup>IL-7R<sup>+</sup>α4β7<sup>−</sup>CD25<sup>−</sup>Flt3<sup>−</sup>), α4β7+ lymphoid progenitors (α-LPs, Lin<sup>−</sup>IL-7R<sup>+</sup>c-Kit<sup>+</sup>α4β7<sup>+</sup>), and ILC2 progenitors (ILC2Ps, Lin<sup>−</sup>IL-7R<sup>+</sup>α4β7<sup>+</sup>CD25<sup>+</sup>Sca-1<sup>+</sup>) revealed no differences in progenitor frequencies or absolute counts between DKO and control mice ([Figures S3](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S3D), consistent with prior reports that ILC3 identity is epigenetically imprinted post-lineage commitment.[<sup>5</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>7</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

Subsequent flow cytometric profiling of small intestinal lamina propria (siLP) ILC3s in control, JKO (_Jmjd3_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>), UKO (_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>), and DKO mice revealed subset-specific perturbations. While total RORγt<sup>+</sup> ILC3 numbers remained unchanged ([Figure S2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)E), NKp46<sup>+</sup> ILC3 frequencies were markedly reduced in UKO (70% decrease) and DKO (70% decrease) mice compared to controls, with JKO showing intermediate effects (25% reduction) ([Figures 2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig2)A and 2E). Conversely, CCR6<sup>+</sup> ILC3 populations expanded significantly in UKO (1.5-fold) and DKO (1.7-fold) mice ([Figures 2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig2)A and 2C), though CCR6<sup>+</sup>CD4<sup>+</sup> ILC3s remained unaffected ([Figure S2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)F).[<sup>5</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>6</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Phenotypically, UKO mice closely mirrored DKO animals, with near-identical subset redistribution patterns, whereas JKO mice displayed attenuated effects—a hierarchy suggesting that UTX dominates over JMJD3 in regulating ILC3 subset equilibrium. Previous studies have demonstrated the phenotypic and functional plasticity of CCR6<sup>−</sup> ILC3 subsets.[<sup>9</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Notably, DN ILC3s serve as precursors to NKp46<sup>+</sup>ILC3s, acquiring NKp46 expression and IFN-γ production through a T-bet-regulated reversible process.[<sup>26</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>28</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) The total number of ILC3s remains unchanged, suggesting that this may subset-specific redistribution rather than global proliferation or depletion. In this process, UTX and JMJD3, as demethylases of H3K27me3, may orchestrate ILC plasticity and differentiation by modulating epigenetic landscapes. Interestingly, the effect of JKO alone is less pronounced than that of UKO and DKO, indicating that UTX and JMJD3 may have partial functional overlap or synergistic roles.

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/1aff6339-a71a-4d9e-b06d-566bd0f4a321/main.assets/gr2.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/6b18e091-bee4-455d-a6b5-8b792d8199e0/main.assets/gr2_lrg.jpg "View full size image in a new tab")

Figure 2 H3K27me3 demethylases orchestrate intestinal ILC3 homeostasis

To further confirm cell-intrinsic regulation, competitive BM chimeras were generated by transplanting CD45.2<sup>+</sup> DKO or control BM cells mixed 1:1 with CD45.1<sup>+</sup> wild-type (WT) cells into lethally irradiated recipients. At 8 weeks post-transplant, donor-derived (CD45.2<sup>+</sup>) NKp46<sup>+</sup> ILC3s exhibited selective depletion in DKO chimeras (38.9% vs. 67% in Ctrls), while CCR6<sup>+</sup> ILC3s showed reciprocal expansion ([Figures 2](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig2)F and 2G). Notably, CCR6<sup>−</sup>NKp46<sup>−</sup> ILC3s remained unchanged, and splenic reconstitution efficiency was comparable between groups, underscoring the intrinsic role of UTX/JMJD3 in maintaining ILC3 subset equilibrium.[<sup>6</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>8</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) These findings align with emerging paradigms of epigenetic regulation in immune cell plasticity, where histone-modifying enzymes fine-tune transcriptional programs to balance effector and regulatory functions.[<sup>5</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>6</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

### JMJD3/UTX deficiency impairs CCR6<sup>−</sup> ILC3-mediated antimicrobial defense through cell-intrinsic IL-22 dysregulation

The genetic ablation of _Jmjd3_ and _Utx_ in ILC3s resulted in profound subset-specific functional perturbations. Building on our findings of ILC3 homeostasis disruption, we hypothesized that the observed shifts in NKp46<sup>+</sup> ILC3 and CCR6<sup>+</sup> ILC3 composition might correlate with cytokine dysregulation. To test this, lamina propria ILC3s from DKO and Ctrl mice were subjected to _ex vivo_ IL-23/IL-1β stimulation ([Figures S4](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S4D). Quantitative analysis revealed a significant reduction in the frequencies of IL-22<sup>+</sup> NKp46<sup>+</sup> ILC3s and DN ILC3s in DKO mice, whereas the proportion of the IL-22<sup>+</sup> CCR6<sup>+</sup> ILC3 subpopulation remained unchanged, although a downward trend in cell numbers was observed ([Figures S4](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)E and S4F). This dichotomy underscores a non-redundant role for JMJD3/UTX in preserving IL-22 competency specifically within NKp46<sup>+</sup> and DN subsets.[<sup>9</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>10</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

To validate these functional defects _in vivo_, we employed a _Citrobacter rodentium_ (CR) colitis model, where ILC3-derived IL-22 is critical for bacterial clearance and mucosal protection.[<sup>8</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>11</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) DKO mice exhibited severe disease progression, characterized by significant colonic shortening, higher fecal CR burdens, and accelerated weight loss compared to Ctrls ([Figures 3](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig3)A–3D). Hematoxylin and eosin staining confirmed transmural inflammation and crypt hyperplasia in DKO mice ([Figure 3](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig3)E). Flow cytometry revealed that IL-22 was significantly downregulated in NKp46<sup>+</sup> ILC3s, along with a marked decrease in total ILC3s and DN ILC3s ([Figures 3](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig3)F–3K), directly linking JMJD3/UTX deficiency to impaired antimicrobial responses.[<sup>9</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>10</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/0c303c18-13d2-4f5d-80da-43ea37091cd7/main.assets/gr3.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/a45490f0-41c2-40e8-98ae-ffef8095a62a/main.assets/gr3_lrg.jpg "View full size image in a new tab")

Figure 3 Epigenetic regulation of IL-22 production governs _Citrobacter rodentium_ susceptibility in DKO mice

To exclude adaptive immunity confounders, we performed ILC3-specific functional validation in immunodeficient NCG mice. Adoptive transfer of DKO ILC3s into CR-infected NCG recipients resulted in exacerbated pathology: shortened colons, 3-fold higher fecal CR loads, and severe weight loss ([Figures 4](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig4)A–4D). Histological analysis confirmed more severe pathology, including mucosal erosion and massive cellular infiltration of the lamina propria, and the normal structure of some mucosa was evidently damaged in DKO ILC3 recipients ([Figure 4](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig4)E), conclusively demonstrating that JMJD3/UTX intrinsically regulate ILC3 effector functions during enteric infection.[<sup>10</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>11</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/a1e19566-ff8f-411d-b0d7-1eac50c3f9e4/main.assets/gr4.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/692bff81-d272-4d79-9e32-fc7dd0c444f6/main.assets/gr4_lrg.jpg "View full size image in a new tab")

Figure 4 Cell-intrinsic requirement for H3K27me3 demethylases in ILC3-mediated _C. rodentium_ defense

These data collectively establish JMJD3/UTX as critical epigenetic gatekeepers of ILC3-mediated immunity, orchestrating IL-22-dependent microbial clearance through subset-specific chromatin remodeling. The cell-intrinsic nature of this regulatory axis highlights its potential as a therapeutic target for IBDs and enteric infections.[<sup>9</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>10</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

### Epigenetic regulation of NKp46<sup>−</sup> ILC3 effector plasticity augments antifungal immunity via enhanced IL-17A production

Building on our findings of altered ILC3 subset abundance in DKO mice, we investigated whether CCR6<sup>+</sup> ILC3 phenotypic shifts coincided with functional reprogramming of IL-17A secretion.[<sup>13</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>14</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Flow cytometric analysis of phorbol 12-myristate 13-acetate (PMA)/ionomycin-stimulated lamina propria lymphocytes (LPLs) revealed a distinct increase in IL-17A<sup>+</sup>CCR6<sup>+</sup> ILC3s, NKp46<sup>+</sup> ILC3s, and DN ILC3s ([Figures S5](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S5F).

To assess the _in vivo_ relevance of this epigenetic reprogramming, we employed a _Candida albicans_ (SC5314 strain) oropharyngeal infection model. DKO mice exhibited enhanced fungal clearance, evidenced by 2.1-log lower fecal colony-forming units (CFUs), attenuated colonic shortening, and less intestinal damage ([Figures 5](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig5)A–5C and 5E). Notably, DKO mice maintained body weight ([Figure 5](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig5)D), aligning with IL-17A’s known role in mucosal antifungal defense.[<sup>14</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>15</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Flow cytometry confirmed IL-17A hyperproduction in CCR6<sup>+</sup> and DN ILC3s, while NKp46<sup>+</sup> subsets remained unaffected ([Figures 5](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig5)F–5K). These data demonstrate that UTX/JMJD3 ablation selectively potentiates IL-17A competency in CCR6<sup>+</sup> and DN subsets while dysregulating IL-22<sup>−</sup>NKp46<sup>+</sup> crosstalk, suggesting a bifurcation in epigenetic control of cytokine programs across ILC3 subsets. To exclude adaptive immunity confounders, we adoptively transferred sorted ILC3s from DKO or control mice into NCG immunodeficient recipients prior to _C. albicans_ challenge. DKO ILC3 recipients exhibited superior fungal control: significantly lower fecal CFUs, preserved colon length, and mitigated weight loss compared to Ctrls ([Figures S6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S6D). Histopathology revealed intact crypt architecture and reduced neutrophil infiltration in DKO recipients ([Figure S6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)E), corroborating cell-intrinsic enhancement of IL-17A-mediated antifungal responses.

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/2a1369af-8dd2-441e-b03a-8aa72b97cc4b/main.assets/gr5.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/175952d3-27a4-483d-ab9b-3666ac6ee3df/main.assets/gr5_lrg.jpg "View full size image in a new tab")

Figure 5 H3K27me3 demethylase deficiency enhances antifungal immunity via ILC3-derived IL-17A

These findings establish UTX/JMJD3 as epigenetic brakes restraining ILC3 effector plasticity. Their deletion unlocks a hyperinflammatory CCR6<sup>+</sup> ILC3 state, potentiating IL-17A-driven immunity against fungal pathogens—a mechanism with translational implications for recalibrating mucosal defenses in immunocompromised hosts.[<sup>11</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>16</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

### Transcriptional atlas reveals UTX/JMJD3 that govern ILC3 lineage plasticity through epigenetic-transcriptional coupling

To elucidate the mechanistic basis by which UTX and JMJD3 maintain ILC3 subset equilibrium, we performed single-cell RNA sequencing (scRNA-seq) on intestinal ILC3s isolated from _Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> and Ctrl mice. After rigorous quality control (QC)[<sup>4</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) to exclude low-quality cells and those with elevated mitochondrial transcripts (indicative of stress or apoptosis), 6,203 high-quality cells passed stringent QC metrics, enabling robust resolution of intestinal ILC3 heterogeneity ([Figure 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)A).

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/639dc57c-56f4-4b0f-8170-e38280495d58/main.assets/gr6.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/fd212ab0-ddfd-4b5b-810e-13f22e4db1ba/main.assets/gr6_lrg.jpg "View full size image in a new tab")

Figure 6 JMJD3/UTX deficiency reprograms the transcriptional landscape of intestinal ILC3s

t-Distributed stochastic neighbor embedding (t-SNE) projection identified seven transcriptionally distinct clusters ([Figure 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)A), all belonging to the ILC3 lineage as evidenced by uniform _Rorc_ (RORγt) expression ([Figure 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)B). Cluster 0 was annotated as CCR6<sup>+</sup> ILC3s based on high expression of _Ccr6_ and LTi-like signature genes (_Ll17f_ and _Nrp1_), with a subset co-expressing _Cd4_ ([Figures 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)B–6D). Cluster 1 was defined as NKp46<sup>+</sup> ILC3s via _Ncr1_ and _Tbx21_ enrichment, alongside cytotoxic markers (_Ctsw_ and _Socs2_) and _Ifng_ ([Figure 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)B). Clusters 2–6 lacked CCR6 or NKp46 lineage-defining markers and were classified as DN ILC3s, representing a transitional precursor pool.

Of note, genotype-driven clustering revealed that UTX/JMJD3 deficiency profoundly altered subset dynamics. RNA velocity analysis uncovered impaired differentiation trajectories from DN ILC3s to NKp46<sup>+</sup> ILC3s (cluster 1), evidenced by diminished velocity arrows and reduced cluster 1 frequency in DKO mice ([Figures 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)E–6G). Conversely, DN ILC3s in DKO mice exhibited enhanced transcriptional flux toward CCR6<sup>+</sup> ILC3s (cluster 0), correlating with expanded cluster 0 proportions ([Figures 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)E–6G). Gene set enrichment analysis (GSEA) corroborated these findings: CCR6<sup>+</sup> ILC3 signature gene sets were upregulated in DKO mice, while NKp46<sup>+</sup> ILC3 signatures were suppressed ([Figures 6](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig6)H and 6I).

These data collectively demonstrate that UTX/JMJD3 ablation rewires ILC3 lineage commitment by epigenetically constraining DN-to-NKp46<sup>+</sup> differentiation while potentiating CCR6<sup>+</sup> polarization—a mechanism that aligns with recent reports on H3K27me3-mediated suppression of cytotoxic programs in mucosal lymphocytes.[<sup>19</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>20</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) The observed plasticity shifts mirror findings in T helper type 17 (Th17) cells, where JMJD3 deficiency similarly disrupts effector subset balance,[<sup>19</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) underscoring conserved epigenetic principles across innate and adaptive lymphoid lineages.

### UTX orchestrates ILC3 functional plasticity through epigenetic regulation of TCF7

To delineate the genome-wide binding landscape of UTX in intestinal ILC3s, we performed CUT&Tag chromatin profiling, a high-resolution technique for mapping protein-DNA interactions with superior signal-to-noise ratios compared to traditional chromatin immunoprecipitation sequencing (ChIP-seq).[<sup>21</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>22</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Robust UTX enrichment was observed within ±5 kb of peak centers across the ILC3 genome, with negligible signals in IgG Ctrls ([Figures 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)A and 7B). Inspection of genome-wide peak distribution revealed that UTX-bound loci predominantly localized to intergenic regions (47%) and introns (30%) ([Figure S7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A). Analysis of H3K27me3 levels around TSSs (TSS ± 5 kb) revealed a trend toward reduced deposition in deficient NKp46<sup>+</sup> ILC3s, whereas CCR6<sup>+</sup> and DN subsets exhibited minimal changes ([Figure 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)C), suggesting subset-specific epigenetic regulation. Genome-wide H3K27me3 profiling in DKO ILC3s identified hypermethylated loci enriched in intergenic regions (25%) and promoters (25%), implicating H3K27me3 in maintaining repressive chromatin states ([Figure S7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)B). Complementary JMJD3 CUT&Tag profiling ([Figures S8](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A and S8B) revealed substantial overlap with UTX binding across ILC3 subsets, particularly in NKp46<sup>+</sup> ILC3s ([Figure S8](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)C). However, H3K27me3 hypermethylation in DKO mice originated predominantly from UTX-bound loci, with minimal contribution from JMJD3-specific sites, consistent with the more severe phenotype of UKO. Further analysis revealed that UTX-unique, JMJD3-unique, and H3K27me3-unique targets are preferentially enriched across distinct ILC3 subsets, suggesting subset-specific regulatory biases ([Figures S8](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)D, [S9](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A, and S9B).

[![](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/b102b56b-c888-425e-a36f-b7ac6c21bf6f/main.assets/gr7.jpg)](https://www.cell.com/cms/10.1016/j.celrep.2025.116862/asset/56e118c2-9ec9-457d-81c7-c28f1777b859/main.assets/gr7_lrg.jpg "View full size image in a new tab")

Figure 7 Genome-wide chromatin profiling and rescue experiments identify TCF7 as a direct UTX target in NKp46<sup>+</sup> ILC3s

Integrative analysis of UTX binding peaks, H3K27me3 modifications, and RNA-seq data revealed that nearly half of UTX-bound loci exhibited close correlations between H3K27me3 accumulation and transcriptional repression in DKO mice ([Figure 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)D). To directly dissect this regulatory relationship, we integrated our epigenetic and transcriptional datasets, revealing a genome-wide negative correlation between H3K27me3 levels and gene expression across ILC3 subsets, which was most pronounced in NKp46<sup>+</sup> ILC3s ([Figures S10](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)A–S10C). These genes were enriched for transcription factors governing lymphoid differentiation, including _Tcf7_, _Runx3_, _Zbtb7b_, and _Socs3_, all harboring prominent UTX binding peaks at their regulatory regions ([Figures 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)E and [S7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)C). Especially in NKp46<sup>+</sup> and DN ILC3s, UTX/JMJD3 ablation elevated H3K27me3 levels at these loci, concomitant with transcriptional attenuation ([Figure S7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#mmc1)D). Notably, effector genes critical for ILC3 function, including _Il22_ and _Il21r_, also displayed analogous patterns with UTX occupancy and H3K27me3 hypermethylation in DKO ILC3s. This epigenetic rewiring aligns with recent findings that H3K27me3 deposition at cytokine loci suppresses their activation during immune responses.[<sup>23</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>24</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Mechanistically, UTX appears to counteract PRC2-mediated repression by erasing H3K27me3 at these sites, a process requiring JMJD3 cooperation, as evidenced by synergistic effects in dual KOs.[<sup>23</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>24</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

The centrality of _Tcf7_ in this regulatory network was further validated: flow cytometry confirmed _Tcf7_ suppression across DKO ILC3 subsets, which was most pronounced in NKp46<sup>+</sup>ILC3s ([Figures 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)F and 7G). To further explore the role played by Tcf7 in deficient ILC3s, _Tcf7_\-retroviral vectors were transduced into _Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> CLPs, providing long-term modulation of _Tcf7_ expression in infected cells and their progeny. Retrovirus-transfected CLPs were transferred into sublethally irradiated CD45.1<sup>+</sup> recipient mice that were sacrificed 2 weeks later for analysis. The results showed that _Tcf7_ overexpression restored NKp46<sup>+</sup> and CCR6<sup>+</sup> ILC3 frequencies ([Figures 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)H and K). Critically, _Tcf7_ reconstitution normalized IL-22 production and attenuated IL-17A hyperactivation ([Figures 7](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#fig7)I–7K), demonstrating that UTX/JMJD3 govern ILC3 effector functions through _Tcf7_\-mediated chromatin remodeling.

## Discussion

ILCs are vital for mucosal immunity, with ILC3s being key effectors in gut homeostasis and barrier function. ILC3s display remarkable plasticity, enabling them to adapt to diverse microenvironments through epigenetic regulation. Our study identifies the histone demethylases UTX (KDM6A) and JMJD3 (KDM6B) as central epigenetic regulators of ILC3 functional diversification. In the intestinal tract, H3K27me3 modifications selectively mark NKp46<sup>+</sup> ILC3s, and deficiency of UTX/JMJD3 disrupts ILC3 subset equilibrium: NKp46<sup>+</sup> ILC3s are depleted with reduced IL-22 production, while CCR6<sup>+</sup> ILC3s expand and exhibit enhanced IL-17A-mediated antifungal activity. scRNA-seq reveals that UTX/JMJD3 loss restricts DN-to-NKp46<sup>+</sup> differentiation and promotes CCR6<sup>+</sup> polarization by altering chromatin accessibility. Mechanistically, CUT&Tag analysis shows that UTX directly binds to enhancer elements upstream of Tcf7, where it mediates H3K27me3 demethylation to maintain a transcriptionally permissive chromatin state. Functional rescue experiments demonstrate that Tcf7 restoration in UTX-deficient ILC3s normalizes NKp46<sup>+</sup> ILC3 frequencies and IL-22 secretion while reversing CCR6<sup>+</sup> ILC3 expansion and IL-17A hyperactivation. These findings position UTX/JMJD3 as critical epigenetic gatekeepers that ensure a balanced ILC3 repertoire capable of context-specific immune responses, a conserved mechanism across innate and adaptive lymphoid lineages.

The dynamic plasticity of ILC3 subsets and their functional specialization are tightly regulated by epigenetic mechanisms, with histone modifications emerging as critical determinants of lineage commitment and effector programs. Recent studies have highlighted the antagonistic interplay between H3K27me3 (a repressive mark) and H3K4me3 (an activating mark) in defining chromatin accessibility and transcriptional outputs across immune cell populations. For instance, EZH2-mediated H3K27me3 deposition enhances the immunosuppressive function of regulatory T cells (Tregs) by silencing pro-inflammatory loci, thereby driving their differentiation into effector Tregs—a mechanism critical for maintaining immune tolerance in autoimmune diseases and tumor microenvironments.[<sup>29</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Meanwhile, CXXC-finger protein 1 (CXXC1) interacts with the transcription factor FOXP3 and facilitates the regulation of target genes by modulating H3K4me3 deposition, which is essential for the maintenance of Treg homeostasis and their suppressive functions.[<sup>30</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Conversely, the activating H3K4me3 marks exhibit dynamic reciprocity with repressive modifications. The RUVBL1/2 complex, for example, primes pro-inflammatory gene expression in macrophages by orchestrating H3K4me3 distribution at enhancer regions, while its disruption induces a hypo-inflammatory state during lipopolysaccharide (LPS)-induced tolerance.[<sup>31</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>32</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Notably, H3K4me3 serves as a barrier against DNA hypermethylation, preserving transcriptional competence at loci critical for rapid cytokine production in CD4<sup>+</sup> T cells.[<sup>33</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) These findings collectively highlight a dual regulatory paradigm: while H3K27me3 enforces lineage stability by locking cells into immunosuppressive or differentiated states, H3K4me3 licenses transcriptional plasticity to meet contextual immune demands.

In the context of ILC3 biology, the balance between these modifications is particularly crucial, as these cells must rapidly adapt to mucosal environmental cues while maintaining tissue homeostasis. Researchers find that the microbiome shapes the epigenetic and transcriptional landscape of intestinal ILCs, including the methylation state of _Tcf7._[<sup>34</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) This indeed raises the important question of whether UTX/JMJD3 might function as epigenetic mediators that allow ILC3s to interpret and respond to microbial signals. Based on the established role of UTX and JMJD3 as dynamic regulators of the epigenetic landscape in response to environmental cues in other systems,[<sup>35</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>36</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) it is plausible that they serve a similar function in ILC3s. It can be reasonably proposed that UTX and JMJD3 serve as key epigenetic mediators, potentially translating microbial or inflammatory signals into appropriate ILC3 responses by dynamically erasing H3K27me3 at master regulators such as _Tcf7_, thereby safeguarding ILC3 identity and functional flexibility in the ever-changing gut environment. The distribution patterns of H3K4me3 and H3K27me3 likely reflect distinct epigenetic regulatory events experienced by different subsets during development, which determine their maturation states. In line with our finding that H3K27me3 deposition acts as a molecular brake restricting NKp46<sup>+</sup> ILC3 differentiation, the dominance of H3K27me3 in NKp46<sup>+</sup> ILC3s suggests a conserved role for this mark in restraining terminal differentiation, akin to its function in maintaining hematopoietic stem cell quiescence.[<sup>37</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) As shown in our prior study on aged gut ILC3s, H3K4me3 alterations occurred predominantly in CCR6⁺ ILC3s, whereas NKp46⁺ ILC3s and DN ILC3s exhibited minimal changes in comparison.[<sup>25</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) The predominance of H3K4me3 in CCR6<sup>+</sup> ILC3s might enable them to more readily maintain or activate specific gene expressions under certain stimuli, while the predominance of H3K27me3 in NKp46<sup>+</sup> ILC3s may confer greater epigenetic plasticity in response to diverse microenvironmental signals. This dichotomy mirrors adaptive lymphocyte differentiation, where H3K4me3 primes effector programs while H3K27me3 constrains lineage promiscuity.[<sup>24</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)

Our results demonstrate that UTX/JMJD3-mediated H3K27me3 erasure at _Tcf7_ enhancers licenses NKp46<sup>+</sup> subset differentiation. T cell factor 1 (TCF-1), encoded by the transcription factor 7 (_Tcf7_) gene, was first identified as a T lymphocyte-specific transcription factor.[<sup>38</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Numerous studies have shown that TCF-1 plays a pivotal role in the self-renewal and differentiation of hematopoietic progenitor cells.[<sup>39</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Beyond its role in hematopoiesis, TCF-1 is indispensable for immune cell biology: it regulates the development, activation, and homeostasis of T lymphocytes by modulating effector gene expression and integrating signals from key pathways such as Wnt/β-catenin and Notch.[<sup>40</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>41</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>42</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>43</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) In ILCs, TCF-1 emerges as a master regulator of early lineage commitment and subset specification.[<sup>44</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#)<sup>,</sup>[<sup>45</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) TCF-1 upregulation defines early innate lymphoid progenitors (EILPs) in the BM. Furthermore, TCF-1 governs the development of ILC2s.[<sup>46</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) TCF-1 also governs the development of NKp46<sup>+</sup> ILC3s and is required for IL-22 production in CR infection,[<sup>47</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) which is consistent with our findings. Emerging evidence positions TCF-1 as a pivotal regulator of non-LTi ILC development.[<sup>48</sup>](https://www.cell.com/cell-reports/fulltext/S2211-1247(25)01634-1#) Also, TCF-1 represses IL-17 production in siLP LTi cells. This regulatory role aligns with our findings in DKO mice, where CCR6<sup>+</sup> ILC3 development remains intact despite UTX/JMJD3 ablation, while IL-17A secretion is markedly elevated. Our data reveal that UTX directly targets _Tcf7_ enhancers, resolving repressive H3K27me3 to establish an open chromatin configuration. We propose that UTX collaborates with H3K4me3 methyltransferases (e.g., mixed lineage leukemia \[MLL\] complexes) to establish such bivalent chromatin states at key loci such as _Tcf7_, enabling rapid transcriptional switching during ILC3 lineage rewiring. Restoration of NKp46<sup>+</sup> ILC3 frequency and IL-22 production upon _Tcf7_ rescue underscores its role as a downstream effector of UTX, bridging epigenetic regulation to functional specialization.

### Limitations of the study

While our study establishes UTX/JMJD3-mediated H3K27me3 demethylation as a critical regulator of ILC3 plasticity, several limitations should be noted. Although mixed BM chimeras demonstrated a cell-intrinsic requirement for UTX/JMJD3 deletion with _Rorc-cre_, this model involves competitive reconstitution within an irradiated host. Therefore, the observed phenotypes could potentially be influenced by cell competition or by the specific, and possibly altered, mucosal environment of the irradiated and reconstituted host, which may not fully recapitulate steady-state physiology. Furthermore, the potential influence of the gut microenvironment, including commensal microbiota, on this demethylase-dependent regulatory axis remains an important area for future investigation. While we identify TCF7 as a key target, the phenotypic complexity suggests that additional UTX/JMJD3-regulated genes likely contribute to the overall ILC3 dysregulation. Finally, our analysis was conducted predominantly in female mice; thus, potential sex-specific dimensions of this epigenetic regulatory axis warrant future investigation.

## Resource availability

### Lead contact

Requests for further information and resources should be directed to and will be fulfilled by the lead contact, Lie Wang ([wanglie@zju.edu.cn](mailto:wanglie@zju.edu.cn)).

### Materials availability

All materials, reagents, and transgenic lines generated in this article are available upon request to the lead contact. Detailed protocols for experiments reported in this article are available upon request to the lead contact.

### Data and code availability

All the raw sequencing data reported in this paper have been deposited in the Genome Sequence Archive (Genomics, Proteomics & Bioinformatics 2025) in the National Genomics Data Center (Nucleic Acids Res 2025), China National Center for Bioinformation/Beijing Institute of Genomics, Chinese Academy of Sciences ([https://ngdc.cncb.ac.cn/gsa/browse/CRA033096](https://ngdc.cncb.ac.cn/gsa/browse/CRA033096) and [https://ngdc.cncb.ac.cn/gsa/browse/CRA033268](https://ngdc.cncb.ac.cn/gsa/browse/CRA033268), [https://ngdc.cncb.ac.cn/gsa/browse/CRA033355](https://ngdc.cncb.ac.cn/gsa/browse/CRA033355)). This paper does not report original code. Any additional information required to reanalyze the data reported in this paper is available from the lead contact upon request.

## Acknowledgments

We thank Prof. Ju Qiu (Shanghai Institutes for Biological Sciences) for her generous gift of _C. rodentium_. We thank Prof. Guanghua Huang (Fudan University) for his generous gift of _C. albicans_. We thank Yanwei Li, Yingying Huang, and Xin Shen from the Core Facilities, Zhejiang University School of Medicine, for their technical support. We thank Yanxia Ding, Huihui Jin, and Xuliang Zhang from the Animal Facilities, Zhejiang University, for mouse maintenance. The graphical abstract was created in BioRender ([https://BioRender.com/vkcnufn](https://biorender.com/vkcnufn)). This work was supported by grants from the National Natural Science Foundation of China (32341002, 32030035, 32500762, and U25A6003), the National Key R&D Program of China (2023YFA1800202 and 2024YFF0728703), the Science and Technology Innovation 2030-Major Project (2021ZD0200405), and the Fundamental Research Funds for the Central Universities (226-2024-00161). X.S. is supported by the Experimental Technology Research Project of Zhejiang University (grant no. SYBJS202530) and the Research Project on Laboratory Work in Colleges and Universities of Zhejiang Province (YB202447).

## Author contributions

Conceptualization, X.G. and L.W.; methodology, X.G., X.S., Q.X., J.Y., and L.W.; investigation, X.G., X.S., Q.X., L.D., and Y.Z.; resources, S.H., H.J., and Q.W.; formal analysis, X.G.; visualization, X.G. and L.W.; supervision, D.W., L.L., J.Y., and L.W.; writing – original draft, X.G.; and writing – review & editing, X.G., X.S., Q.X., J.Y., and L.W.

## Declaration of interests

The authors declare no competing interests.

## STAR★Methods

### Key resources table

| REAGENT or RESOURCE | SOURCE | IDENTIFIER |
| --- | --- | --- |
| **Antibodies** |
| Biotin CD3e (clone 145-2C11) | eBioscience | Cat#36-0031-85; RRID: [AB\_469747](https://antibodyregistry.org/AB_469747) |
| Biotin TCR gamma/delta (clone GL3) | eBioscience | Cat#13-5711-85; RRID: [AB\_466669](https://antibodyregistry.org/AB_466669) |
| Biotin Ly-6G/Ly-6C (clone RB6-8C5) | eBioscience | Cat#13-5931-82; RRID: [AB\_466800](https://antibodyregistry.org/AB_466800) |
| Biotin TER-119 (clone TER-119) | Biolegend | Cat#116203; RRID: [AB\_313704](https://antibodyregistry.org/AB_313704) |
| Biotin CD19 (clone 1D3) | eBioscience | Cat# 13-0193-86; RRID: [AB\_657655](https://antibodyregistry.org/AB_657655) |
| Biotin CD5 (clone 53–7.3) | Biolegend | Cat#100603; RRID: [AB\_312732](https://antibodyregistry.org/AB_312732) |
| Biotin B220 (clone RA3-6B2) | Biolegend | Cat#10320; RRID:[AB\_312988](https://antibodyregistry.org/AB_312988) |
| Biotin anti-mouse NK-1.1 (clone PK136) | Biolegend | Cat#108703; RRID: [AB\_313390](https://antibodyregistry.org/AB_313390) |
| Biotin anti-mouse CD11c (clone N418) | Biolegend | Cat#117303; RRID: [AB\_313772](https://antibodyregistry.org/AB_313772) |
| Biotin anti-mouse/human CD11b (clone M1/70) | Biolegend | Cat#101203; RRID: [AB\_312786](https://antibodyregistry.org/AB_312786) |
| PE-Cyanine7 anti-CD27 (clone LG.7F9) | eBioscience | Cat#25-0271-82; RRID:[AB\_1724035](https://antibodyregistry.org/AB_1724035) |
| PE Anti-Mouse IL-17A (TC11-18H10) | BD Biosciences | Cat#561020; RRID: [AB\_397256](https://antibodyregistry.org/AB_397256) |
| PE anti-mouse CD45.1 (A20) | Biolegend | Cat# 110707; RRID: [AB\_313496](https://antibodyregistry.org/AB_313496) |
| PE anti-Mouse IFN-γ (XMG1.2) | BD Biosciences | Cat# 554412; RRID: [AB\_395376](https://antibodyregistry.org/AB_395376) |
| PerCP-Cy™5.5 Mouse anti-Ki-67 (B56) | BD Biosciences | Cat# 561284; RRID: [AB\_10611574](https://antibodyregistry.org/AB_10611574) |
| APC-Cy™7 Mouse Anti-Mouse NK-1.1 (PK136) | BD Biosciences | Cat# 560618; RRID: [AB\_1727569](https://antibodyregistry.org/AB_1727569) |
| APC Mouse anti-Mouse CD45.2 (104) | BD Biosciences | Cat# 561875; RRID: [AB\_1645215](https://antibodyregistry.org/AB_1645215) |
| BV421 Mouse Anti-Mouse RORγt (Q31-378) | BD Biosciences | Cat# 562894; RRID: [AB\_2687545](https://antibodyregistry.org/AB_2687545) |
| PE CD127 Monoclonal Antibody (A7R34) | eBioscience | Cat# 12-1271-82; RRID: [AB\_465844](https://antibodyregistry.org/AB_465844) |
| APC IL-22 Monoclonal Antibody (IL22JOP) | eBioscience | Cat# 17-7222-82; RRID: [AB\_10597583](https://antibodyregistry.org/AB_10597583) |
| PE-Cyanine7 KLRG1 Monoclonal Antibody (2F1) | eBioscience | Cat# 25-5893-82; RRID: [AB\_1518768](https://antibodyregistry.org/AB_1518768) |
| APC-Cyanine7 c-Kit Monoclonal Antibody (2B8) | Invitrogen | Cat# A15423; RRID: [AB\_2534436](https://antibodyregistry.org/AB_2534436) |
| PE/Cyanine7 anti-mouse CD196 (29-2L17) | Biolegend | Cat# 129815; RRID: [AB\_1877244](https://antibodyregistry.org/AB_1877244) |
| PE Mouse IgG1 kappa Isotype Control (P3.6.2.8.1) | eBioscience | Cat# 12-4714-82; RRID: [AB\_470060](https://antibodyregistry.org/AB_470060) |
| APC anti-mouse CD8a (53–6.7) | Biolegend | Cat# 100711; RRID: [AB\_312750](https://antibodyregistry.org/AB_312750) |
| PE anti-mouse PLZF Antibody (9E12) | Biolegend | Cat# 145803; RRID: [AB\_2561966](https://antibodyregistry.org/AB_2561966) |
| APC anti-mouse CD335 (NKp46) (29A1.4) | Biolegend | Cat# 137607;  
RRID: [AB\_10612749](https://antibodyregistry.org/AB_10612749) |
| APC/Cyanine7 anti-mouse CD4 (GK1.5) | Biolegend | Cat# 100413; RRID: [AB\_312698](https://antibodyregistry.org/AB_312698) |
| BV650 Streptavidin | BD Biosciences | Cat# 563855; RRID: [AB\_2869528](https://antibodyregistry.org/AB_2869528) |
| APC anti-mouse LPAM-1 (Integrin α4β7) (DATK32) | Biolegend | Cat# 120607; RRID: [AB\_10719833](https://antibodyregistry.org/AB_10719833) |
| PE anti-mouse Ly-6A/E (Sca-1) (D7) | Biolegend | Cat# 108107; RRID: [AB\_313344](https://antibodyregistry.org/AB_313344) |
| PE-Cyanine5 CD135 (Flt3) Monoclonal Antibody (A2F10) | eBioscience | Cat# 15-1351-82; RRID: [AB\_494219](https://antibodyregistry.org/AB_494219) |
| PE Gata-3 Monoclonal Antibody (TWAJ) | eBioscience | Cat# 12-9966-42; RRID: [AB\_1963600](https://antibodyregistry.org/AB_1963600) |
| PE-Cyanine7 EOMES Monoclonal Antibody (Dan11mag) | eBioscience | Cat# 25-4875-82; RRID: [AB\_2573454](https://antibodyregistry.org/AB_2573454) |
| PE AHR Monoclonal Antibody (4MEJJ) | eBioscience | Cat# 12-5925-82; RRID: [AB\_2572644](https://antibodyregistry.org/AB_2572644) |
| PE anti-IRF4 Antibody (IRF4.3E4) | Biolegend | Cat# 646403; RRID: [AB\_2563004](https://antibodyregistry.org/AB_2563004) |
| PE Mouse Anti-RUNX3 | BD Biosciences | Cat# 564814; RRID: [AB\_2738969](https://antibodyregistry.org/AB_2738969) |
| PE IRF4 Monoclonal Antibody (3E4) | eBioscience | Cat# 12-9858-82; RRID: [AB\_10852721](https://antibodyregistry.org/AB_10852721) |
| PE anti-mouse IL-23R Antibody (12B2B64) | Biolegend | Cat# 150903; RRID: [AB\_2572188](https://antibodyregistry.org/AB_2572188) |
| PE anti-T-bet Antibody (4B10) | eBioscience | Cat# 644809; RRID: [AB\_2028583](https://antibodyregistry.org/AB_2028583) |
| PE-conjugated anti–IL-12Rβ1 | R and D Systems | Cat# FAB1998P; RRID: [AB\_10571374](https://antibodyregistry.org/AB_10571374) |
| Anti-BATF (EPR21911) | Abcam | Cat# ab221146; RRID: [AB\_3665801](https://antibodyregistry.org/AB_3665801) |
| Alexa Fluor™ 594 Donkey Anti-Rabbit IgG (H + L) | Cell Signaling | Cat# A21207; RRID: [AB\_2340621](https://antibodyregistry.org/AB_2340621) |
| Normal Rabbit IgG (2729) | Cell Signaling | Cat# 2729S; |
| Anti-Rabbit IgG (H + L) | Sigma-Aldrich | Cat# SAB3700883; |
| **Bacterial and virus strains** |
| DH5α Chemically Competent Cell | Tsingke Biotech | Cat#TSC-C14 |
| _Citrobacter rodentium_ strain DBS100 | ATCC | Stock# 51459 |
| _Candida albicans_ strain SC5314. | Guanghua Huang Lab, Fudan University | Gifted from Prof. Guanghua Huang |
| **Chemicals, peptides, and recombinant proteins** |
| Fixable Viability Dye 450 | eBioscience | Cat#65-0863-14 |
| Fixable Viability Stain 510 | BD | Cat#564406 |
| FBS | Gibco | Cat#10270 |
| PMA | Sigma-Aldric | Cat# P1585 |
| DTT, Molecular Grade (Dry Powder) | Promega | Cat#V3151 |
| Ionomycin | Sigma-Aldric | Cat# I3909 |
| Polybrene | Millpore | Cat# TR-1003-G |
| DNase I | Sigma | Cat# DN25 |
| Collagenase VIII | Sigma Aldrich | Cat#C2139 |
| Percoll | Cytiva | Cat#17-0891-01 |
| PrimeSTAR MAX Premix | TAKARA | Cat# R045A |
| Mouse IL-23 Recombinant Protein | Peprotech | Cat# 14-8231-63 |
| IL-1β | Peprotech | Cat# SRP8033 |
| Interleukin-7 | Peprotech | Cat# I4892 |
| IL-6 | Peprotech | Cat# SRP3330 |
| Murine SCF | Peprotech | Cat#250-03-50 |
| RetroNectin | Takara | Cat#T100A/B |
| **Critical commercial assays** |
| BD Rhapsody™ WTA Amplification Kit | BD Biosciences | Cat# 633801 |
| AMPure® XP magnetic beads | Beckman | Cat# A63880 |
| Qubit™ dsDNA HS Assay Kit | Thermo Fisher Scientific | Cat# Q32851 |
| BD Rhapsody™ Cartridge Reagent Kit | BD Biosciences | Cat# 633731 |
| BD Rhapsody™ cDNA Kit | BD Biosciences | Cat# 633773 |
| **Deposited data** |
| scRNA-seq | This paper | GSE271288 |
| CUT&Tag sequencing | This paper | GSE281331 |
| **Experimental models: cell lines** |
| HEK 293T | ATCC | Cat#ACS-4500 |
| Plat E | Shanghai Institutes for Biological Sciences | Gifted from Prof. Xiaolong Liu |
| **Experimental models: organisms/strains** |
| Mouse:_Kdm6a_<sup><i>flox/flox</i></sup> (Utx) | Jackson Laboratories | Strain #:021926 RRID:IMSR\_JAX:021926 |
| Mouse:_Kdm6b_<sup><i>flox/flox</i></sup>(Jmjd3) | Jackson Laboratories | Strain #:029615 RRID:IMSR\_JAX:029615 |
| Mouse:Rorc-cre | Jackson Laboratories | Strain #: 022791 RRID:IMSR\_JAX:022791 |
| Mouse: NCG | GemPharmatech (Nanjing, China) | Strain #:T001475 |
| Mouse:CD45.1 | Jackson Laboratories | Strain #: 002014 RRID:IMSR\_JAX:002014 |
| **Deposited data** |
| RNAseq data | This paper | CRA033355 |
| CUT&Tag | This paper | CRA033268 |
| ATACseq | This paper | CRA033096 |
| **Oligonucleotides** |
| RORγt-cre genotyping. Forward:  
GGAAAATGCTTCTGTCCGTTTG | Tsingke Biotech | N/A |
| RORγt-cre genotyping. Reverse:  
TTGGTCCAGCCACCAGCTTG | Tsingke Biotech | N/A |
| **Recombinant DNA** |
| pMX-IRES-tdTomato | This paper | N/A |
| **Software and algorithms** |
| GraphPad Prism v8 | GraphPad | [https://www.graphpad.com/guides/prism/8/userguide/tips\_for\_using\_prism.htm](https://www.graphpad.com/guides/prism/8/userguide/tips_for_using_prism.htm) |
| FlowJo v10 | TreeStar | [https://www.flowjo.com/solutions/flowjo/downloads](https://www.flowjo.com/solutions/flowjo/downloads) |
| R version 4.0.2 | R Core | [https://www.R-project.org/](https://www.r-project.org/) |
| Adobe Illustrator | Adobe | [https://www.adobe.com/cn/](https://www.adobe.com/cn/) |
| **Other** |
| Dynabeads® Biotin Binder | Thermo Fisher Scientific | Cat#11047 |

### Experimental model and study participant details

#### Mice and ethics statement

The _Jmjd3_<sup><i>f/f</i></sup> and _Utx_<sup><i>f/f</i></sup> mouse strain were purchased from the Jackson Laboratory (Bar Harbor, ME). The _Rorc_\-cre tool mice (JAX: 022791) were generously provided by Prof. Ju Qiu (Shanghai Institutes for Biological Sciences, Chinese Academy of Sciences). _Jmjd3_<sup><i>f/f</i></sup> and _Utx_<sup><i>f/f</i></sup> mice were crossed with _Rorc_\-cre mice to generate the respective conditional knockout strains. NOD Prkdc<sup>em26Cd52</sup>Il2rg<sup>em26Cd22</sup>/Nju (NCG, T001475) mice were acquired from Nanjing Biomedical Research Institute of Nanjing University. CD45.1 mice (2 months old) were obtained from the Zhejiang University Laboratory Animal Center. All mice used in our study were 6-8-week-old virgin female mice. For the phenotypic analysis involving single-knockout (_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>, _Jmjd3_<sup><i>f/f</i></sup>_Rorc_<sup><i>cre</i></sup>) and double-knockout (_Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>) mice, these single-knockout and double-knockout mice were derived from different parental cages. Mice of different genotypes (_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>, _Jmjd3_<sup><i>f/f</i></sup>_Rorc_<sup><i>cre</i></sup>, _Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>) were co-housed together for at least one week prior to any experimental procedure. For infection model experiments (_Citrobacter_ or _Candida_), we used WT (_Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup>) and DKO (_Jmjd3_<sup><i>f/f</i></sup>_Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup>) mice that were littermate controls from the same cage. All animal procedures were approved by the Institutional Animal Care and Use Committee, and the mice were bred and maintained under specific pathogen-free conditions at the Zhejiang University Laboratory Animal Center.

### Method details

#### Isolation of intestinal lamina propria lymphocytes (LPLs)

Lamina propria lymphocytes (LPLs) were isolated from the small intestine using an established protocol. Briefly, the small intestine was dissected, and adipose tissue and Peyer’s patches were carefully removed. The intestine was longitudinally opened, cut into 5 mm segments, and washed in DMEM. Tissue fragments were then incubated under continuous agitation in DMEM containing 3% fetal bovine serum (FBS), 0.2% Hanks’ Balanced Salt Solution (HBSS), 0.5 M EDTA, and 0.145 mg/mL dithiothreitol (DTT) for 10 min to eliminate epithelial cells. Subsequent enzymatic digestion was carried out using 50 μg/mL DNase I (Sigma-Aldrich) and 1.45 mg/mL Collagenase II (Worthington Biochemical) in DMEM medium at 37°C for 30 min with periodic vortexing. The cell suspension was filtered through a 100 μm strainer, and lymphocytes were enriched via discontinuous Percoll (GE Healthcare) gradient centrifugation. LPLs collected from the interphase were washed twice in PBS containing 2% FBS and processed for downstream analyses.

#### Cell stimulation and flow cytometry

To evaluate cytokine secretion, _ex vivo_ lamina propria lymphocytes (LPLs) were resuspended in DMEM supplemented with 50% fetal bovine serum (FBS) and stimulated for 4 h at 37°C. For IL-22 production, cells were treated with IL-23 (Pepro Tech, 40 ng/mL) and IL-1β (Pepro Tech, 20 ng/mL), while IL-17A production was induced using PMA (Sigma-Aldrich, 50 ng/mL) and ionomycin (Sigma-Aldrich, 1 mg/mL). To inhibit cytokine secretion, brefeldin A (BFA, 1000×, Invitrogen) was added 0.5 h post-stimulation.

Dead cells were labeled using Fixable Viability Dye (eBioscience), and Fc receptors were blocked using anti-CD16/32 (clone 93, Biolegend). Bone marrow precursor cells were identified using lineage markers targeting TCRγδ, CD3ε, CD19, B220, NK1.1, CD11b, CD11c, Gr-1, and Ter119. Peripheral innate lymphoid cells (ILCs) were detected using a lineage cocktail containing TCRγδ, CD3ε, CD19, CD5, Gr-1, and Ter119. For intracellular staining of transcription factors or cytokines, cells were first stained for surface markers, then fixed and permeabilized using the Foxp3/Transcription Factor Staining Buffer Set (Invitrogen) according to the manufacturer’s instructions. Flow cytometry was performed using a BD Fortessa (BD Biosciences), and data were analyzed using FlowJo10 software. Cell sorting was performed by an FACSAria II flow cytometer and Moflo Astrios EQ (Beckman). The following antibodies were sourced from eBioscience, BD Biosciences, or Biolegend: CD4 (RM4-5), CD8α (53–6.7), IL-17A (TC11-18H10), TCR-β (H57-597), CD27 (LG.7F9), CD25 (PC61.5), NK1.1 (PK136), IL-22 (IL22JOP), Eomes (Dan11mag), PLZF (B263557), CD45.2 (104), Ki67 (B56), RORγt (Q31-378), Flt3 (A2F10), NKp46 (29A1.4), KLRG1 (2F1), GATA3 (TWAJ), CD127 (A7R34), CD117 (2B8), CCR6 (29-2L17), B220 (RA3-6B2), Sca-1 (D7), Isotype (P3.6.2.8.1), IgM (II/41), α4β7 (DATK32), CD45.1 (A20), and Streptavidin. Apoptosis was assessed using the Annexin V-FITC Apoptosis Kit (Lianke).

#### Bone marrow chimeras

To generate bone marrow chimeras, CD45.2<sup>+</sup> bone marrow cells isolated from _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice were mixed with CD45.1<sup>+</sup> wild-type bone marrow cells in an equal ratio. The cell mixture was then intravenously injected into half lethally irradiated CD45.1<sup>+</sup> wild-type recipient mice. Eight weeks post-transplantation, intestinal ILC3s originating from CD45.2<sup>+</sup> donor cells were assessed using flow cytometrynnn.

#### _C. rodentium_ infection

_Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice were orally inoculated with 5 × 10<sup>9</sup> CFUs of _C. rodentium_ (DBS100) following a 1-week treatment with an antibiotic cocktail (autoclaved water supplemented with ampicillin 1 g/L, gentamicin 1 g/L, metronidazole 1 g/L, and vancomycin 0.5 g/L). Body weight was monitored daily for seven days, and the mice were euthanized on day 7. Fecal samples were weighed and plated on MacConkey agar to quantify bacterial colonies. Small intestines were harvested for lymphocyte isolation and subsequently analyzed for IL-22 production. Colon lengths were measured, and the tissues were fixed in 4% methanol for 24 h prior to hematoxylin and eosin (H&E) staining.

#### _C. albicans_ infection

_C. albicans s_train SC5314 was cultured in YPD (yeast nitrogen base with 2% glucose, 100 μg/mL ampicillin, 0.01 mg/mL vancomycin, 0.1 mg/mL gentamicin). _C. albicans_ (1 × 10<sup>8</sup> CFUs) was administered to _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice by gavage after 3-day ABX-1 (autoclaved water supplemented with streptomycin 2 mg/mL, fluconazole 0.2 mg/mL and gentamicin 0.2 mg/mL) treatment. ABX-I was replaced with ABX-II (Streptomycin 2 mg/mL, Gentamicin 0.2 mg/mL, and Ampicillin 2 mg/mL) on day 3 and lasted until the end of the model. Body weight changes were monitored in the following seven days, and all mice were sacrificed on day 11. Subsequent steps were consistent with the _C. rodentium_ model, except for the identification of IL-17A expression.

#### Cell adoptive transfer into NCG mice

NCG mice were adoptively transferred with eighty thousand intestinal ILC3s (Lin<sup>−</sup>CD127<sup>+</sup>CD27<sup>−</sup>KLRG1<sup>-</sup>) sorted from _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice or PBS as control after treated with ABX for 1 week. ILC3s were stimulated with IL-23 and IL-1β for 30 min before being injected into NCG mice through the tail vein. NCG mice were orally inoculated with _C. rodentium_ 24 h after adoptive transfer. Body weight was monitored for 9 days, and all mice were sacrificed for further analysis on day 9.

NCG mice were adoptively transferred with eighty thousand intestinal ILC3s sorted from _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice or PBS as control after 3-day ABX-1 treatment. ILC3s were stimulated with PMA and ionomycin for 30 min before injected to NCG mice through the tail vein. ABX-I was replaced with ABX-II at day 3 and lasted until the end of the model. _C. albicans_ was administered to NCG mice by gavage 24 h after adoptive transfer. Body weight was monitored for 9 days, and all mice were sacrificed for further analysis at day 9.

#### Histology

Colons were removed intact, fixed in 4% paraformaldehyde and embedded in paraffin. Subsequently, the tissues were sectioned and stained with hematoxylin and eosin following standard laboratory protocols.

#### ATAC-seq

ATAC-seq libraries were performed on 150,000 sort-purified ILC3 subsets (CCR6<sup>+</sup> ILC3, DN ILC3, NKp46<sup>+</sup> ILC3) from the small intestinal lamina propria (siLP) of _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice, following the manufacturer’s protocol of the TruePrep DNA Library Prep Kit V2 for Illumina (Vazyme, TD501/TD502/503) with minor modifications. Briefly, fresh cells were collected and washed with PBS. Nuclei were isolated using a chilled lysis buffer (10 mM Tris-HCl pH 7.4, 10 mM NaCl, 3 mM MgCl<sub>2</sub>, 0.1% Igepal CA-630) and incubated on ice for 10 min. After centrifugation, nuclei pellets were resuspended in a transposase reaction mix containing 5×TTBL and TTE Mix V50, and incubated at 37°C for 30 min. The fragmented DNA was purified using VAHTS DNA Clean Beads (Vazyme N411). Purified fragments were amplified by PCR using TruePrep Index Kit primers (Vazyme TD202/TD203/TD204) with the following program: 72°C for 3 min; 98°C for 30 s; then 12–15 cycles of 98°C for 15 s, 60°C for 30 s, and 72°C for 30 s. Amplified libraries were purified again with magnetic beads and optionally size-selected using a 0.55×/1× bead-based strategy to enrich fragments between 200 and 700 bp. Library quality was assessed using the Qubit dsDNA HS Assay Kit (Vazyme EQ111) and fragment size distribution was analyzed on an Agilent 2100 Bioanalyzer. Libraries showing a nucleosomal pattern with a dominant peak around 200 bp were used for subsequent sequencing.

#### CUT&Tag and bioinformatics analysis

H3K27me3, H3K4me3 and UTX chromatin immunoprecipitation (ChIP) assays were performed on 100,000 sort-purified ILC3 subsets (CCR6<sup>+</sup> ILC3, DN ILC3, NKp46<sup>+</sup> ILC3) from the small intestinal lamina propria (siLP) of _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice, following the protocol outlined in the Hyperactive _In-Situ_ ChIP Library Prep Kit for Illumina (TD 901, Vazyme). Briefly, sorted ILC3 cells were washed twice with 500 μL of wash buffer supplemented with 1× protease inhibitor cocktail (Sigma-Aldrich, 5056489001). The cell pellets were then resuspended in wash buffer and incubated with Concanavalin A-coated magnetic beads at room temperature. Following incubation, the bead-bound cells were resuspended in 50 μL of antibody buffer, and 1 μg of Tri-Methyl-Histone H3 (Lys27) antibody (CST, C36B11), Histone H3 trimethyl Lys4 antibody (Active Motif, 39916), anti-UTX antibody (Bethyl, A302-374A), or Normal Rabbit IgG (CST, 2729) was added. The mixture was incubated overnight at 4°C with gentle rotation. After removal of the primary antibody, 50 μL of secondary antibody (goat anti-rabbit IgG, Sigma-Aldrich, SAB3700883) diluted 1:100 in Dig-wash buffer was added and incubated at room temperature. Subsequently, the cells were incubated with 0.04 μM Hyperactive pG-Tn5 Transposase (diluted in Dig-300 buffer) at room temperature for 1 h with slow rotation. The cells were then resuspended in tagmentation buffer and incubated at 37°C for 1 h. DNA was purified using phenol-chloroform-isoamyl alcohol extraction followed by ethanol precipitation after terminating tagmentation. DNA library amplification was performed according to the manufacturer’s instructions and cleaned using VAHTS DNA Clean Beads (Vazyme). The libraries were sequenced on an Illumina NovaSeq platform, generating 150-bp paired-end reads.

All raw sequence data were quality trimmed using fastp (version 0.19.7) and aligned to the mm10 mouse genome using Bowtie2 (version 2.3.5.1) with options'-local-very-sensitive-local-no-unal-nomixed-no-discordant-phred33-I10-X700'. PCR duplicates were removed using Picard MarkDuplicates (version 2.25.0). Peaks were called using MACS2 (version 2.2.7.1) with options 'q 0.05'. DeepTools2 software (version 3.5.1) was used to create the peaks density plot and heatmap graph. Visualization of peak distribution along genomic regions of interested genes was performed with IGV. Genomic annotation was assigned using ChIPSeeker (version 1.28.3). Promoters were defined as follows: within 3,000 bp around the TSS. Differential expression analysis of two groups was performed using DESeq2 (version 1.30.1).

#### Single-cell RNA sequencing

To investigate the transcriptional profiles of ILC3 subsets in the context of genetic modifications, 300,000 sort-purified ILC3s were isolated from the small intestinal lamina propria (siLP) of _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup>cre</sup> mice. The cells were resuspended in BD Pharmingen Stain Buffer containing fetal bovine serum (FBS) (BD Biosciences, 554656). Sample tags were applied to the cells using the BD Mouse Immune Single-Cell Multiplexing Kit (BD Biosciences, 633793) to enable multiplexing of samples. Single-cell capture and cDNA synthesis were performed using the BD Rhapsody Single-Cell Analysis System, which allows for high-throughput single-cell RNA sequencing. Subsequently, single-cell RNA sequencing (scRNA-seq) libraries were constructed using the BD Rhapsody WTA Amplification Kit (BD Biosciences, 633801), following the standard protocol provided by the manufacturer.

#### scRNA-seq data analysis

The fastq files generated from single-cell RNA sequencing were processed using the BD Rhapsody Targeted Analysis Pipeline on the Seven Bridges platform. Initially, read pairs with a mean base quality score below 20 were discarded to ensure high-quality data. The remaining R1 reads were analyzed to identify cell label sequences and unique molecular identifiers (UMIs). R2 reads were then aligned to the mouse genome (mm10) using Bowtie2 (version 2.3.5.1). Valid reads were collapsed into single raw molecules based on identical cell labels, UMI sequences, and gene assignments. To correct for sequencing and PCR errors, recursive substitution error correction (RSEC) was applied to the raw UMI counts. The RSEC-adjusted molecule matrices were utilized for downstream analyses.

For quality control, cells with mitochondrial UMI counts exceeding 25% or fewer than 200 detected genes were excluded from further analysis. The Scanpy workflow was employed for comprehensive downstream analyses. Specifically, the following steps were performed: (1) log1pCP10K normalization of the raw counts; (2) selection of highly variable genes; (3) regression analysis to account for the effects of the total count per cell and the percentage of mitochondrial gene count; (4) calculation of the first 50 principal components; (5) application of Harmony to eliminate sample-level batch effects; (6) dimensionality reduction using UMAP; (7) clustering of single cells via the Leiden algorithm, an unsupervised graph-based method; (8) identification of cluster-specific marker genes using Student’s _t_ test; and (9) annotation of clusters based on the expression patterns of literature-derived marker genes.

To specifically analyze ILC3s, cells positive for Rorc but negative for Cd3d were extracted from the integrated atlas. The data for these ILC3s were reprocessed from the raw counts and further subclustered to delineate finer cell states, namely NKp46<sup>+</sup>, CCR6<sup>+</sup>, and CCR6<sup>−</sup>NKp46<sup>-</sup> subsets.

#### RNA velocity analysis

For each sample, a.loom file containing counts categorized into spliced, unspliced, and ambiguous was generated using the velocyto.py toolkit (version 0.17). The data were then pre-processed using the scVelo Python toolkit (version 0.2.4). Genes detected in fewer than 20 counts were filtered out, and the top 2000 genes with the highest variability were selected for further analysis. Following normalization and logarithmization, the first and second-order moments (means and uncentered variances) were computed among nearest neighbors in PCA space using default parameters. RNA velocity was subsequently estimated using the scVelo function scv.tl.velocity(), and visualized using the scv.pl.velocity\_embedding\_stream() function.

#### Gene function of ILCs for _in vivo_ analysis using retroviral transduction

Retroviruses were generated by transfecting pMX-IRES-GFP plasmids containing the indicated genes into Plat-E cells using PolyJet (SignaGen). Media were replaced 12/18 h after transfection, and retroviral supernatants were collected after 48 h. For transduction, 48-well plates were coated with RetroNectin (TaKaRa, 25 μg mL−1) overnight at 4°C. After blocking with BSA and washing, 1 mL of supernatant was added and followed by centrifugation for 2 h at 1,500g at 32°C.

The bone marrow from _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> and _Jmjd3_<sup><i>f/f</i></sup> _Utx_<sup><i>f/f</i></sup> _Rorc_<sup><i>cre</i></sup> mice was aspirated to create a single-cell suspension. Common lymphoid progenitors (CLPs; Lin<sup>−</sup>CD127<sup>+</sup>c-Kit<sup>int</sup>Sca-1<sup>int</sup>Flt3<sup>+</sup>) were enriched by Dynabeads Biotin Binder (Invitrogen) after lineage staining and then superficially stained and sorted. CLPs were resuspended in CLP medium (αMEM medium containing 10% FBS, penicillin–streptomycin, 1× non-essential amino acids, 1 mM sodium pyruvate, 2 mM L-glutamine, 20 mM HEPES, and 50 μM β-ME) and plated at 100,000 cells per well in the presence of IL-7 (20 ng mL−1), IL-6 (10 ng mL−1), SCF (100 ng mL−1), Flt3L (20 ng mL−1), TPO (10 ng mL−1), and polybrene (Merck, 5 μg mL−1). Ten hours later, retrovirus-transfected CLPs were collected and adoptively transferred into sublethally irradiated CD45.1+ wild-type recipient mice through intravenous tail vein injection. Transduced cells were transferred with CD45.1+ wild-type bone marrow cells to facilitate the engraftment of the CLPs. After 2 weeks, recipient mice were sacrificed, and organs were collected for analysis.

### Quantification and statistical analysis

#### Statistical analyses of RNA-seq data

Single-cell RNA-seq data were processed with standard pipelines to define cell populations. Differential expression and downstream enrichment analyses used two-sided Wilcoxon rank-sum tests with Benjamini–Hochberg FDR correction (adjusted _p_ < 0.05), unless otherwise noted.

#### Statistical analysis of non-RNA-seq data

The statistical test used, definition of significance, and number of biological replicates are reported in the figure legends; n denotes the number of independent biological samples (mice, as specified) and ranged from 3 to 7 unless otherwise indicated. Data from these experiments are presented as mean values ± SEM. A two-tailed Student’s _t_ test was performed for comparisons between two groups. All statistical analyses were performed using GraphPad Prism software (version 8, GraphPad Software). The same samples were not repeatedly measured, and no data points were excluded from the analysis. The confidence interval was set at 95% for statistical analysis.

## Supplemental information (2)

Document S1. Figures S1–S10

Document S2. Article plus supplemental information

## References

Vivier, E. ∙ Artis, D. ∙ Colonna, M. ...

**Innate Lymphoid Cells: 10 Years On**

_Cell._ 2018; **174**:1054-1066

Klose, C.S.N. ∙ Artis, D.

**Innate lymphoid cells control signaling circuits to regulate tissue-specific immunity**

_Cell Res._ 2020; **30**:475-491

Clottu, A.S. ∙ Humbel, M. ∙ Fluder, N. ...

**Innate Lymphoid Cells in Autoimmune Diseases**

_Front. Immunol._ 2022; **12**, 789788

Jacquelot, N. ∙ Seillet, C. ∙ Vivier, E. ...

**Innate lymphoid cells and cancer**

_Nat. Immunol._ 2022; **23**:371-379

Mebius, R.E.

**Organogenesis of lymphoid tissues**

_Nat. Rev. Immunol._ 2003; **3**:292-303

Meier, D. ∙ Bornmann, C. ∙ Chappaz, S. ...

**Ectopic lymphoid-organ development occurs through interleukin 7-mediated enhanced survival of lymphoid-tissue-inducer cells**

_Immunity._ 2007; **26**:643-654

Klose, C.S.N. ∙ Artis, D.

**Innate lymphoid cells as regulators of immunity, inflammation and tissue homeostasis**

_Nat. Immunol._ 2016; **17**:765-774

Klose, C.S.N. ∙ Kiss, E.A. ∙ Schwierzeck, V. ...

**A T-bet gradient controls the fate and function of CCR6-RORgammat+ innate lymphoid cells**

_Nature._ 2013; **494**:261-265

Melo-Gonzalez, F. ∙ Hepworth, M.R.

**Functional and phenotypic heterogeneity of group 3 innate lymphoid cells**

_Immunology._ 2017; **150**:265-275

Artis, D. ∙ Spits, H.

**The biology of innate lymphoid cells**

_Nature._ 2015; **517**:293-301

Keir, M. ∙ Yi, T. ∙ Lu, T. ...

**The role of IL-22 in intestinal health and disease**

_J. Exp. Med._ 2020; **217**, e20192195

Cherrier, M. ∙ Ramachandran, G. ∙ Golub, R.

**The interplay between innate lymphoid cells and T cells**

_Mucosal Immunol._ 2020; **13**:732-742

Bagadia, P. ∙ Huang, X. ∙ Liu, T.T. ...

**Shared Transcriptional Control of Innate Lymphoid Cell and Dendritic Cell Development**

_Annu. Rev. Cell Dev. Biol._ 2019; **35**:381-406

Stehle, C. ∙ Rückert, T. ∙ Fiancette, R. ...

**T-bet and RORalpha control lymph node formation by regulating embryonic innate lymphoid cell differentiation**

_Nat. Immunol._ 2021; **22**:1231-1244

Rankin, L.C. ∙ Groom, J.R. ∙ Chopin, M. ...

**The transcription factor T-bet is essential for the development of NKp46+ innate lymphocytes via the Notch pathway**

_Nat. Immunol._ 2013; **14**:389-395

Cella, M. ∙ Otero, K. ∙ Colonna, M.

**Expansion of human NK-22 cells with IL-7, IL-2, and IL-1beta reveals intrinsic functional plasticity**

_Proc. Natl. Acad. Sci. USA._ 2010; **107**:10961-10966

Vonarbourg, C. ∙ Mortha, A. ∙ Bui, V.L. ...

**Regulated expression of nuclear receptor RORgammat confers distinct functional fates to NK cell receptor-expressing RORgammat(+) innate lymphocytes**

_Immunity._ 2010; **33**:736-751

Verrier, T. ∙ Satoh-Takayama, N. ∙ Serafini, N. ...

**Phenotypic and Functional Plasticity of Murine Intestinal NKp46+ Group 3 Innate Lymphoid Cells**

_J. Immunol._ 2016; **196**:4731-4738

Peng, V. ∙ Xing, X. ∙ Bando, J.K. ...

**Whole-genome profiling of DNA methylation and hydroxymethylation identifies distinct regulatory programs among innate lymphocytes**

_Nat. Immunol._ 2022; **23**:619-631

Zhang, X. ∙ Gao, X. ∙ Liu, Z. ...

**Microbiota regulates the TET1-mediated DNA hydroxymethylation program in innate lymphoid cell differentiation**

_Nat. Commun._ 2024; **15**:4792

Antignano, F. ∙ Braam, M. ∙ Hughes, M.R. ...

**G9a regulates group 2 innate lymphoid cell development by repressing the group 3 innate lymphoid cell program**

_J. Exp. Med._ 2016; **213**:1153-1162

Su, X. ∙ Zhao, L. ∙ Zhang, H. ...

**Sirtuin 6 inhibits group 3 innate lymphoid cell function and gut immunity by suppressing IL-22 production**

_Front. Immunol._ 2024; **15**, 1402834

Chang, J. ∙ Ji, X. ∙ Deng, T. ...

**Setd2 determines distinct properties of intestinal ILC3 subsets to regulate intestinal immunity**

_Cell Rep._ 2022; **38**, 110530

Wei, G. ∙ Wei, L. ∙ Zhu, J. ...

**et al. Global Mapping of H3K4me3 and H3K27me3 Reveals Specificity and Plasticity in Lineage Fate Determination of Differentiating CD4 T Cells**

_Immunity._ 2009; **30**:155-167

Shen, X. ∙ Gao, X. ∙ Luo, Y. ...

**Cxxc finger protein 1 maintains homeostasis and function of intestinal group 3 innate lymphoid cells with aging**

_Nat. Aging._ 2023; **3**:965-981

Klose, C.S.N. ∙ Kiss, E.A. ∙ Schwierzeck, V. ...

**A T-bet gradient controls the fate and function of CCR6 RORγt innate lymphoid cells**

_Nature._ 2013; **494**:261-265

Sawa, S. ∙ Cherrier, M. ∙ Lochner, M. ...

**Lineage Relationship Analysis of RORγt Innate Lymphoid Cells**

_Science._ 2010; **330**:665-669

Rankin, L.C. ∙ Groom, J.R. ∙ Chopin, M. ...

**The transcription factor T-bet is essential for the development of NKp46 innate lymphocytes via the Notch pathway (vol 14, pg 389, 2013)**

_Nat. Immunol._ 2013; **14**:877

Peeters, J.G.C. ∙ Silveria, S. ∙ Ozdemir, M. ...

**Hyperactivating EZH2 to augment H3K27me3 levels in regulatory T cells enhances immune suppression by driving early effector differentiation**

_Cell Rep._ 2024; **43**, 114724

Meng, X. ∙ Zhu, Y. ∙ Liu, K. ...

**CXXC-finger protein 1 associates with FOXP3 to stabilize homeostasis and suppressive functions of regulatory T cells**

_eLife._ 2025; **13**, 103417

Zhang, R. ∙ Cheung, C.Y. ∙ Seo, S.U. ...

**RUVBL1/2 Complex Regulates Pro-Inflammatory Responses in Macrophages Regulating Histone H3K4 Trimethylation**

_Front. Immunol._ 2021; **12**:679184

Ruenjaiman, V. ∙ Butta, P. ∙ Leu, Y.W. ...

**Profile of Histone H3 Lysine 4 Trimethylation and the Effect of Lipopolysaccharide/Immune Complex-Activated Macrophages on Endotoxemia**

_Front. Immunol._ 2020; **10**, 2956

LaMere, S.A. ∙ Thompson, R.C. ∙ Komori, H.K. ...

**Promoter H3K4 methylation dynamically reinforces activation-induced pathways in human CD4 T cells**

_Genes Immun._ 2016; **17**:283-297

Gury-BenAri, M. ∙ Thaiss, C.A. ∙ Serafini, N. ...

**The Spectrum and Regulatory Landscape of Intestinal Innate Lymphoid Cells Are Shaped by the Microbiome**

_Cell._ 2016; **166**:1231-1246.e13

Nakka, K. ∙ Hachmer, S. ∙ Mokhtari, Z. ...

**JMJD3 activated hyaluronan synthesis drives muscle regeneration in an inflammatory environment**

_Science._ 2022; **377**:666-669

Shan, Y. ∙ Zhang, Y. ∙ Zhao, Y. ...

**JMJD3 and UTX determine fidelity and lineage specification of human neural progenitor cells**

_Nat. Commun._ 2020; **11**:382

Damele, L. ∙ Amaro, A. ∙ Serio, A. ...

**EZH1/2 Inhibitors Favor ILC3 Development from Human HSPC-CD34 Cells**

_Cancers._ 2021; **13**, ARTN319

Vandewetering, M. ∙ Oosterwegel, M. ∙ Dooijes, D. ...

**Identification and Cloning of Tcf-1, a Lymphocyte-T-Specific Transcription Factor Containing a Sequence-Specific Hmg Box**

_Embo J._ 1991; **10**:123-132

Wu, J.Q. ∙ Seay, M. ∙ Schulz, V.P. ...

**Tcf7 Is an Important Regulator of the Switch of Self-Renewal and Differentiation in a Multipotential Hematopoietic Cell Line**

_PLoS Genet._ 2012; **8**, e1002565

Zhao, X. ∙ Shan, Q. ∙ Xue, H.H.

**TCF1 in T cell immunity: a broadened frontier**

_Nat. Rev. Immunol._ 2022; **22**:147-157

Sun, Q. ∙ Cai, D. ∙ Liu, D. ...

**BCL6 promotes a stem-like CD8 T cell program in cancer via antagonizing BLIMP1**

_Sci. Immunol._ 2023; **8**, eadh1306

Harly, C. ∙ Kenney, D. ∙ Wang, Y. ...

**A Shared Regulatory Element Controls the Initiation of Expression During Early T Cell and Innate Lymphoid Cell Developments**

_Front. Immunol._ 2020; **11**:470

Weber, B.N. ∙ Chi, A.W.S. ∙ Chavez, A. ...

**A critical role for TCF-1 in T-lineage specification and differentiation**

_Nature._ 2011; **476**:63-68

Yang, Q. ∙ Li, F. ∙ Harly, C. ...

**TCF-1 upregulation identifies early innate lymphoid progenitors in the bone marrow**

_Nat. Immunol._ 2015; **16**:1044-1050

Harly, C. ∙ Kenney, D. ∙ Ren, G. ...

**The transcription factor TCF-1 enforces commitment to the innate lymphoid cell lineage**

_Nat. Immunol._ 2019; **20**:1150-1160

Yang, Q. ∙ Monticelli, L.A. ∙ Saenz, S.A. ...

**T Cell Factor 1 Is Required for Group 2 Innate Lymphoid Cell Generation**

_Immunity._ 2013; **38**:694-704

Mielke, L.A. ∙ Groom, J.R. ∙ Rankin, L.C. ...

**TCF-1 Controls ILC2 and NKp46 RORγt Innate Lymphocyte Differentiation and Protection in Intestinal Inflammation**

_J. Immunol._ 2013; **191**:4383-4391

Zheng, M. ∙ Yao, C. ∙ Ren, G. ...

**Transcription factor TCF-1 regulates the functions, but not the development, of lymphoid tissue inducer subsets in different tissues**

_Cell Rep._ 2023; **42**, 112924