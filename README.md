# ACL Reviewer Matching Code

This is an initial pass at code to match reviewers for the [ACL Conferences](https://aclweb.org).
It is based on paper matching between abstracts of submitted papers and a database of papers from
[Semantic Scholar](https://www.semanticscholar.org).

## Usage Instructions

### Part 1: Installing and Training Model (before review process)

#### Step 0: download the github repo to your local machine, saved it to a local directory.
   Every step after that is done from that local directory.

#### Step 1:install requirements:

    pip install -r reviewer-paper-matching/requirements.txt
    
#### Step 2: get ACL authology abstracts from semantic scholar.

There are two options. Choose Option B if you are short of diskspace.

**(Option A):** Download the semantic scholar dump
[following the instructions](https://api.semanticscholar.org/corpus/download/). Note that the dump
takes up about 150 GB of disk space, so Option B is recommended if your available diskspace is any
more constrained than this.

Wherever you downloaded the semantic scholar dump, make a virtual link to the `s2` directory here.

    ln -s /path/to/semantic/scholar/dump s2

Make a scratch directory where we'll put working files

    mkdir -p scratch/
    
For efficiency purposes, we'll filter down the semantic scholar dump to only papers where it has a
link to aclweb.org, a rough approximation of the papers in the ACL Anthology.

    zcat s2/s2-corpus*.gz | grep aclweb.org > scratch/acl-anthology.json

**(Option B):** Find the numeric date associated with the Semantic Scholar release you want
(e.g. 2021-01-01), and use the `download_s2.sh` script to iteratively download a chunk of the
release and filter the ACL entries into `acl-anthology.json`. Once all ACL entries have been added
to the anthology file, the s2 chunk will be deleted from disk. This script will automatically create
the `scratch` folder as well as `scratch/acl-anthology.json`. The necessary arguments to the script
are the release date and the number of chunks you want the release to be broken into (based on your
disk capacity):

    ./reviewer-paper-matching/download_s2.sh 2021-01-01 10

#### Step 3: Train a model of semantic similarity based on the ACL anthology (this step requires
GPU). Alternatively, you may contact the authors to get a model distributed to you.

**(3a):** ????
    bash reviewer-paper-matching/download_sts17.sh
    
**(3b):**: tokenize ACL anthology abstracts:    
    python reviewer-paper-matching/tokenize_abstracts.py \
        --infile scratch/acl-anthology.json \
        --outfile scratch/abstracts.txt
 
**(3c):**: create a model file for tokenization and retokenize ACL anthology abstracts:
    python reviewer-paper-matching/sentencepiece_abstracts.py \
        --infile scratch/abstracts.txt \
        --vocab-size 20000 \
        --model-name scratch/abstracts.sp.20k \
        --outfile scratch/abstracts.20k.sp.txt 
        
**(3d):**: create a similarity model:
    python -u reviewer-paper-matching/train_similarity.py \
        --data-file scratch/abstracts.20k.sp.txt \
        --model avg \
        --dim 1024 \
        --epochs 20 \
        --ngrams 0 \
        --share-vocab 1 \
        --dropout 0.3 \
        --batchsize 64 \
        --megabatch-size 1 \
        --megabatch-anneal 10 \
        --seg-length 1 \
        --outfile scratch/similarity-model.pt \
        --sp-model scratch/abstracts.sp.20k.model 2>&1 | tee scratch/training.log

  Is the similarity between words? Or are we creating word embedding?
  
  
### Part 2: Creating Assignments (during review process)

#### Step 1: Create csv files from softconf.

In START, go to the Spreadsheet Maker and download CSV spreadsheets for
"Author/Reviewer Profiles" and "Submissions", saving them to `scratch/Profile_Information.csv` and
`scratch/Submission_Information.csv`. 

**(1a) create scatch/Profile_Information.csv from softconf:

In the Spreadsheet Maker, the necessary fields to download for "Author/Reviewer Profiles" are
`Username`, `Email`, `First Name`, `Last Name`, `Semantic Scholar ID`, `Roles`, `PCRole`, and 
`emergencyReviewer`. **Note:** The ACL COI-detection scripts also use the author/reviewer profiles
as input, and require the additional fields `Previous Affiliations`, `Affiliation Type`,
`COIs Entered on Global Profile`, `Backup Email`, and `Year of Graduation`.

**(1b) create scratch/Submission_Information.csv from softconf:



#### Step 2 (optional): create scratch/bids.csv that stores COI info:


The file bids.csv indicates COI
relationships (as a matrix) between reviewers (columns) and submissions (rows).

To generate this file, we can use softconf and/or an external COI-detection system, 
resulting in three options:
(i) run step 2a only, (ii) run step 2b only, and (iii) run Step 2a first and then Step 2b (which takes the output of 2a as input).

We recommend the third option.

**(2a) get scratch/start_bid.csv from softonf:

In the Spreadsheet Maker, ....

**(2b) Run the external COI-detection system to create scratch/bids.csv.

Contact ACL for the github site for the COI-detection system. The code will use scratch/start_bid.csv from Step 2a and add more COIs.
The output of this system is scratch/bids.csv. If Step 2a is not run first, this system will give a warning.



#### Step 3: Process the files from Step 1-2 into the jsonl and npy format, which are used in Step 4:

    python softconf_extract.py \
        --profile_in=scratch/Profile_Information.csv \
        --submission_in=scratch/Submission_Information.csv \
        --bin_in=scratch/bids.csv \
        --reviewer_out=scratch/reviewers.jsonl \
        --submission_out=scratch/submissions.jsonl \
        --bid_out=scratch/cois.npy

The first three arguments are input files (created in Step 1 and 2), and the last three
arguments are output files. This step processes the input files (e.g., use RegEx to clean some data)
and save the results to jsonl and numpy files, 

The `bid_in` argument (if provided) comes from Step 2. If this argument is not provided, no COIs will be initialized.


#### Step 4: Create and save the reviewer assignments:

    python suggest_reviewers.py \
        --submission_file=scratch/submissions.jsonl \
        --db_file=scratch/acl-anthology.json \
        --reviewer_file=scratch/reviewers.jsonl \
        --model_file=scratch/similarity-model.pt \
        --max_papers_per_reviewer=5 \
        --reviews_per_paper=3 \
        --suggestion_file=scratch/assignments.jsonl

You will then have assignments written to both the terminal and `scratch/assignments.jsonl`. You can
modify `reviews_per_paper` and `max_papers_per_reviewer` to change the number of reviews assigned to
each paper and max number of reviews per reviewer. After you've output the suggestions, you can also
print them (and save them to a file `scratch/assignments.txt`) in an easier-to-read format by
running:

    python suggest_to_text.py < scratch/assignments.jsonl | tee scratch/assignments.txt
    
    
#### Step 5: If you want to turn these into START format to re-enter them into START, you can run the
following command:

    python softconf_package.py \
        --suggestion_file scratch/assignments.jsonl \
        --softconf_file scratch/start-assignments.csv
    
then import `scratch/start-assignments.csv` into start using the data import interface.

**NOTE:** This step also requires an additional dependency, you can install it via
`pip install slugify`

### Evaluating Assignments (to test the model)

**Step 1:** In order to evaluate the system, you will need either (a) a conference with
gold-standard bids, or (b) some other way to create information about bids automatically.

**Step 1a:** If you have gold-standard bids, in START, go to the "Spreadsheet Maker" and download
CSV spreadsheets for "Submissions," "Author/Reviewer Profiles," and "Bids" saving them to
`scratch/Submission_Information.csv` and `scratch/Profile_Information.csv`, and
`scratch/Bid_Information.csv`. Then run the following:

    python softconf_extract.py \
        --profile_in=scratch/Profile_Information.csv \
        --submission_in=scratch/Submission_Information.csv \
        --bids_in=scratch/Bid_Information.csv \
        --reviewer_out=scratch/reviewers.jsonl \
        --submission_out=scratch/submissions.jsonl \
        --bid_out=scratch/bids.npy
        
**Step 1b:** If you do not have this information from START, do the same as above but without
`--bids_in`. Then you will have to create a numpy array `bids.npy` where rows correspond to
submissions, and columns correspond to the bids of potential reviewers (0=COI, 1=no, 2=maybe,
3=yes).

**Step 2:** Follow the steps in the previous section on reviewer assignment to generate
`assignments.jsonl`.

**Step 3:** Evaluate the assignments using the following command:

        python evaluate_suggestions.py \
            --suggestion_file=scratch/assignments.jsonl \
            --reviewer_file=scratch/reviewers.jsonl \
            --bid_file=scratch/bids.npy

This will tell you the ratio of assignments that were made to each bid, where in general a higher
ratio of "3"s is better.

## Method Description

The method for suggesting reviewers works in three steps. First, it uses a model to calculate the
perceived similaritybetween paper abstracts for the submitted papers and papers that the reviewers
have previously written. Then, it aggregates the similarity scores for each paper into an overall
similarity score between the reviewer and the paper. Finally, it performs a reviewer assignment,
assigning reviewers to each paper given constraints on the maximimum number of papers per reviewer.

### Similarity Between Paper Abstracts

The method for measuring similarity of paper abstracts is based on the subword or character
averaging method described in the following paper:

    @inproceedings{wieting19simple,
        title={Simple and Effective Paraphrastic Similarity from Parallel Translations},
        author={Wieting, John and Gimpel, Kevin and Neubig, Graham and Berg-Kirkpatrick, Taylor},
        booktitle={Proceedings of the Association for Computational Linguistics},
        url={https://arxiv.org/abs/1909.13872},
        year={2019}
    }

We trained a model on abstracts from the ACL anthology to attempt to make the similarity model as
topically appropriate as possible. After running this model, this gives us a large matrix of
similarity scores between submitted papers, and papers where at least one of the reviewers in the
reviewer list is an author on the paper.

### Reviewer Score Aggregation

Next, we aggregate the paper-paper matching scores into paper-reviewer matching scores. Assume that
`S_r` is the set of all papers written by a reviewer `r`, and `p` is a submitted paper.
The paper-reviewer matching score of this paper can be calculated in a number of ways, but currently
this code uses the following by default:

    match(p,r) = max(match(S_r,p)) + second(match(S_r,p)) / 2 + third(match(S_r,p)) / 3

Where `max`, `second`, and `third` indicate the reviewer's best, second-best, and third-best
matching paper's scores, respectively. The motivation behind this metric is based on the intuition
that we would both like a reviewer to have written at least one similar paper (hence the `max`) and
also have experience in the field moving beyond a single paper, as the one paper they have written
might be an outlier (hence the `second` and `third`).

The code for this function, along with several other alternatives, can be found in
`suggest_reviewers.py`'s `calc_aggregate_reviewer_score` function.

### Reviewer Assignment

Finally, the code suggests an assignment of reviewers. This is done by trying to maximize the
overall similarity score for all paper-reviewer matches, under the constraint that each paper should
have exactly `reviews_per_paper` reviewers and each reviewer should review a maximum of
`max_papers_per_reviewer` reviews. This is done by solving a linear program that attempts to
maximize the sum of the reviewer-paper similarity scores based on these constraints.

# Credits

This code was written/designed by Graham Neubig, John Wieting, Arya McCarthy, Amanda Stent,
Natalie Schluter, and Trevor Cohn.

