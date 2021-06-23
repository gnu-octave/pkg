////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2021 The Octave Project Developers
//
// See the file COPYRIGHT.md in the top-level directory of this
// distribution or <https://octave.org/copyright/>.
//
// This file is part of Octave.
//
// Octave is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Octave is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Octave; see the file COPYING.  If not, see
// <https://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////

#include <string>
#include <algorithm>
#include <iostream>

#include <octave/oct.h>

// The following algorithm is based on the idea of
//
//    https://norvig.com/spell-correct.html
//
// and the C++ implementation by
//
//    https://github.com/felipefarinon/spellingcorrector

// Internal data structure for suggestions.
std::map<std::string, int> dictionary;


bool sortBySecond(const std::pair<std::string, int>& left,
                  const std::pair<std::string, int>& right)
{
  return left.second < right.second;
}


// Create all sorts of possible corrections `results` of `word`.
void edits(const std::string& word, std::vector<std::string>& results)
{
  // Deletions
  for (std::string::size_type i = 0; i < word.size(); i++)
    results.push_back(word.substr(0, i) + word.substr(i + 1));
  // Transpositions
  for (std::string::size_type i = 0; i < word.size() - 1; i++)
    results.push_back(word.substr(0, i) + word[i + 1] + word[i] + word.substr(i + 2));

  for (char j = 'a'; j <= 'z'; ++j)
  {
    // Alterations
    for (std::string::size_type i = 0; i < word.size(); i++)
      results.push_back(word.substr(0, i) + j + word.substr(i + 1));
    // Insertions
    for (std::string::size_type i = 0; i < word.size() + 1; i++)
      results.push_back(word.substr(0, i) + j + word.substr(i));
  }
}


// Reduce `results` to `candidates`, which are contained in `dictionary`.
void known(std::vector<std::string>& results,
           std::map<std::string, int>& candidates)
{
  std::map<std::string, int>::iterator end = dictionary.end();

  for (unsigned int i = 0; i < results.size(); i++)
    {
      std::map<std::string, int>::iterator value = dictionary.find(results[i]);

      if (value != end)
        candidates[value->first] = value->second;
    }
}


// Main routine for finding a correction.
std::string correct(const std::string& word)
{
  std::vector<std::string> result;
  std::map<std::string, int> candidates;

  // Try if "word" is already matching a dictionary entry.
  if (dictionary.find(word) != dictionary.end())
    return word;

  // Try if one edit of "word" is already matching a dictionary entry.
  edits (word, result);
  known (result, candidates);
  if (candidates.size() > 0)
    return max_element(candidates.begin(), candidates.end(), sortBySecond)->first;

  // Try if second edit of "word" (one edit of "result[i]") is already
  // matching a dictionary entry.
  for (unsigned int i = 0; i < result.size(); i++)
    {
      std::vector<std::string> subResult;

      edits (result[i], subResult);
      known (subResult, candidates);
    }

  if (candidates.size() > 0)
    return max_element (candidates.begin(), candidates.end(), sortBySecond)->first;

  return "";
}


DEFUN_DLD (string_suggestion, args, nargout,
           "-*- texinfo -*-\n\
@deftypefn {} {@var{str} = } string_suggestion (@var{word}, @var{WORDS})\n\
\n\
Return most likely correction of @var{word} from given @var{WORDS}\n\
or an empty string if no correction counld be found.\n\
@end deftypefn")
{
  if (args.length () != 2)
    print_usage ();

  // Read word to correct.
  std::string word = args(0).string_value ();

  // Fill dictionary with word of second argument.
  Cell c = args(1).cell_value ();
  for (octave_idx_type i = 0; i < c.numel (); i++)
    {
      // Give all entries the same "weight" of "1".
      // Weighting not implementated yet.
      dictionary[c(i).string_value ()] = 1;
    }

  return ovl (correct (word));
}
