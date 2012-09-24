module Sim {
	/* Each similarity returned is encapsulated in a sim data object. */
	typedef structure {
		string id1; 
		string id2;
		float bit_score;
		float p_score;
	} sim;

	typedef structure {
	    int kb_only;
	} options;
	/* Retrieve similarities for a set of identifiers. */
	funcdef get_sims(list<string> ids, options options) returns (list<sim>);
};
