class Allergies:

	allergy_score_dict = {'eggs' : 1, 'peanuts' : 2, 'shellfish' : 4, 'strawberries' : 8, 'tomatoes' : 16, 'chocolate' : 32, 'pollen' : 64, 'cats' : 128}

	allergy_score_rev_dict = {1 : 'eggs', 2 : 'peanuts', 4: 'shellfish', 8 : 'strawberries', 16 : 'tomatoes', 32 : 'chocolate', 64 : 'pollen', 128 : 'cats'}

	def __init__(self, allergy_score):
		self.allergy_score = allergy_score

	def is_allergic_to(self, allergy):
		if self.allergy_score == 0:
			return False
		else:
			allergy_list = []
			if self.allergy_score in Allergies.allergy_score_rev_dict:
				return True
			else:
				return True


	def list(self):
		if self.allergy_score in Allergies.allergy_score_rev_dict:
			return [Allergies.allergy_score_rev_dict[self.allergy_score]]

		list_allergins = []

		def recursive_calc(val_list, target, partial=[], reached=False):
			s = sum(partial)
			if s == target:
				reached = True
				return partial
			for i in range(len(val_list)):
				n = val_list[i]
				remaining = val_list[i+1:]
				if not reached:
					recursive_calc(remaining, target, partial + [n], reached)

		matching_allergins = recursive_calc(Allergies.allergy_score_rev_dict.keys(), self.allergy_score)
		print "match " + str(matching_allergins)
		if matching_allergins is None:
			return [Allergies.allergy_score_rev_dict.values()[0]]
		for match in matching_allergins:
			list_allergins.append(Allergies.allergy_score_rev_dict[match])
		return list_allergins

	