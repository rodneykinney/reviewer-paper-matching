# ACL Reviewer Matching Code

This is an initial pass at code to match reviewers for the [ACL Conferences](http://aclweb.org).
It is based on paper matching between abstracts of submitted papers and a database of papers from
[Semantic Scholar](https://www.semanticscholar.org).

## Installing

**Step 1:** install requirements:

    pip install -r requirements.txt
    
**Step 2:** Download the semantic scholar dump
[following the instructions](http://api.semanticscholar.org/corpus/download/).

**Step 3:** Wherever you downloaded the semantic scholar dump, make a virtual link to the `s2` directory here.

    ln -s /path/to/semantic/scholar/dump s2

**Step 4:** Make a scratch directory where we'll put working files

    mkdir -p scratch/
    
**Step 5:** For efficiency purposes, we'll filter down the semantic scholar dump to only papers where it has a link to
aclweb.org, a rough approximation of the papers in the ACL Anthology.

    zcat s2/s2-corpus*.gz | grep aclweb.org > scratch/acl-anthology.json

**Step 6:** In the scratch directory, create two files of paper abstracts `scratch/abstracts.txt` and reviewer names
`scratch/reviewers.txt`.

**Step 7:** Train a model of semantic similarity based on the ACL anthology.

TODO: finish up directions

## Method Description

The method for suggesting reviewers works in three steps. First, it uses a model to calculate the perceived similarity
between paper abstracts for the submitted papers and papers that the reviewers have previously written. Then, it
aggregates the similarity scores for each paper into an overall similarity score between the reviewer and the paper.
Finally, it performs a reviewer assignment, assigning reviewers to each paper given constraints on the maximimum number
of papers per reviewer.

### Similarity Between Paper Abstracts

The method for measuring similarity of paper abstracts is based on the subword or character averaging method described
in the following paper:

    @inproceedings{wieting19simple,
        title={Simple and Effective Paraphrastic Similarity from Parallel Translations},
        author={Wieting, John and Gimpel, Kevin and Neubig, Graham and Berg-Kirkpatrick, Taylor},
        booktitle={Proceedings of the Association for Computational Linguistics},
        url={https://arxiv.org/abs/1909.13872},
        year={2019}
    }

We trained a model on abstracts from the ACL anthology to attempt to make the similarity model as topically appropriate
as possible. After running this model, this gives us a large matrix of similarity scores between submitted papers, and
papers where at least one of the reviewers in the reviewer list is an author on the paper.

### Reviewer Score Aggregation

Next, we aggregate the paper-paper matching scores into paper-reviewer matching scores. Assume that `S_r` is the set of
all papers written by a reviewer `r`, and `p` is a submitted paper. The paper-reviewer matching score of this paper
can be calculated in a number of ways, but currently this code uses the following by default:

    match(p,r) = max(match(S_r,p)) + second(match(S_r,p)) / 2 + third(match(S_r,p)) / 3

Where `max`, `second`, and `third` indicate the reviewer's best, second-best, and third-best matching paper's scores,
respectively. The motivation behind this metric is based on the intuition that we would both like a reviewer to have
written at least one similar paper (hence the `max`) and also have experience in the field moving beyond a single paper,
as the one paper they have written might be an outlier (hence the `second` and `third`).

The code for this function, along with several other alternatives, can be found in `suggest_reviewers.py`'s 
`calc_aggregate_reviewer_score` function.

### Reviewer Assignment

Finally, the code suggests an assignment of reviewers. This is done by trying to maximize the overall similarity score
for all paper-reviewer matches, under the constraint that each paper should have exactly `reviews_per_paper` reviewers
and each reviewer should review a maximum of `max_papers_per_reviewer` reviews. This is done by solving a linear program
that attempts to maximize the sum of the reviewer-paper similarity scores based on these constraints.

# Credits

This code was written/designed by Graham Neubig, John Wieting, Arya McCarthy, and Amanda Stent.

