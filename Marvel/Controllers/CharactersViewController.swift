//
//  CharactersViewController.swift
//  Marvel
//
//  Created by Thiago Lioy on 14/11/16.
//  Copyright © 2016 Thiago Lioy. All rights reserved.
//

import UIKit
import RxSwift
import RxDataSources
import RxCocoa
import Action
import NSObject_Rx


final class CharactersViewController: UIViewController {
    
    
    let containerView = CharactersContainerView()
    var viewModel: CharactersViewModel
    
    let collectionDataSource = RxCollectionViewSectionedReloadDataSource<CharacterSection>()
    
    init(viewModel: CharactersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension CharactersViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataSource()
        setupNavigationItem()
        setupSearchBar()
        bindDatasource()
        fetchCharacters()
    }
    
    override func loadView() {
        self.view = containerView
    }
}

extension CharactersViewController {
    
    func setupNavigationItem() {
        self.navigationItem.title = "Characters"
        self.navigationItem.rightBarButtonItems = [
            NavigationItems.grid(viewModel.switchToGridPresentation()).button(),
            NavigationItems.list(viewModel.switchToListPresentation()).button()
        ]
    }
    
    fileprivate func configureDataSource() {
        
        collectionDataSource.configureCell = {
            dataSource, collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(for: indexPath,
                                               cellType: CharacterCollectionCell.self)
            cell.setup(item: item)
            return cell
        }
        
    }
    
    func updateUI(for state: PresentationState) {
        switch state {
        case .collection:
            containerView.charactersTable.isHidden = true
            containerView.charactersCollection.isHidden = false
        case .table:
            containerView.charactersTable.isHidden = false
            containerView.charactersCollection.isHidden = true
        }
    }
    
    func updateLoadingState(for result: Result<[Character]>) {
        if case .loading = result {
            containerView.activityIndicator.isHidden = false
            containerView.activityIndicator.startAnimating()
        } else {
            containerView.activityIndicator.stopAnimating()
        }
    }
    
    func bindDatasource() {
        
        viewModel.presentationState
            .asObservable()
            .skip(1)
            .subscribe(onNext: {[weak self] state in
                self?.updateUI(for: state)
            }).addDisposableTo(self.rx_disposeBag)
        
        
        
        let itemsObs = viewModel.sectionedItems
            .asObservable()
            
        containerView.charactersTable
            .bindItems(observable: itemsObs)
        
        containerView.charactersTable
            .rowSelectedObservable()
            .subscribe(onNext:{
                self.viewModel.presentDetails(of: $0)
            }).addDisposableTo(rx_disposeBag)
        
        
        //Bind SectionItems on collection
        itemsObs
            .bindTo(containerView.charactersCollection
                .rx.items(dataSource: collectionDataSource))
            .addDisposableTo(self.rx_disposeBag)
        
        
        //Handle click on collectionView's item
        containerView.charactersCollection.rx
            .itemSelected
            .asObservable()
            .map { [unowned self] indexPath in
                try! self.collectionDataSource.model(at: indexPath) as! Character
            }
            .subscribe(onNext:{
                _ = self.viewModel.presentDetails(of: $0)
            })
            .addDisposableTo(rx_disposeBag)
        
    }
    
    
    
    func fetchCharacters(for query: String? = nil) {
        
        let fetchObservable = viewModel.fetchCharacters(with: query)
            .shareReplay(1)
        
        fetchObservable
            .subscribe { event in
                if let element = event.element {
                    self.updateLoadingState(for: element)
                }
        }.addDisposableTo(rx_disposeBag)
        
        fetchObservable
            .subscribe { event in
                if case .completed = event{
                    self.updateUI(for: self.viewModel.presentationState.value)
                }
            }.addDisposableTo(rx_disposeBag)
        
        fetchObservable
            .map({
                if case Result.completed(let characters) = $0 {
                    return characters
                }
                return []
            })
            .map{[ CharacterSection(model: "", items: $0)]}
            .asDriver(onErrorJustReturn: [])
            .drive(self.viewModel.sectionedItems)
            .addDisposableTo(self.rx_disposeBag)
    }
    
    func setupSearchBar() {
        containerView.searchBar.searchCallback = { [weak self] query in
            self?.fetchCharacters(for: query)
        }
    }
    
    
}

